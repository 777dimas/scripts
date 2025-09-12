#!/bin/bash
# Run script: sudo ./multipass_restore.sh >> /var/log/multipass-restore.log 2>&1

RESTORE_DIR="/backups/restore"
S3_BUCKET="multipass-backup"

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    /usr/bin/echo "Error: Required command '$1' is not installed or not in PATH."
    exit 1
  fi
}

/usr/bin/echo "Checking required tools..."
check_command /usr/local/bin/aws
check_command /usr/bin/curl
check_command /usr/bin/snap
check_command /snap/bin/multipass

check_vms_state() {
  VM_STATUS_OUTPUT=$(/snap/bin/multipass list --format csv | tail -n +2 | awk -F',' '{print $3}' | grep -v "Stopped")
  if [ -z "$VM_STATUS_OUTPUT" ]; then
    /usr/bin/echo "All VMs are stopped."
  else
    /usr/bin/echo "Some VMs are still running:"
    /snap/bin/multipass list
  fi
}

check_haproxy_state() {
  /usr/bin/echo "Checking HAProxy status..."
  if /usr/bin/systemctl is-active --quiet haproxy.service; then
    /usr/bin/echo "HAProxy is running"
  else
    /usr/bin/echo "HAProxy is stopped"
  fi
}

if [ "$EUID" -ne 0 ]; then
  /usr/bin/echo "Error: Script must be run with superuser privileges (sudo)."
  exit 1
fi

if [ -z "$SLACK_WEBHOOK_URL" ]; then
  /usr/bin/echo "Error: SLACK_WEBHOOK_URL environment variable is not set."
  exit 1
fi

notify_slack() {
    local MESSAGE="$1"
    /usr/bin/curl -s -X POST -H 'Content-type: application/json' \
         --data "{\"text\":\"${MESSAGE}\"}" "$SLACK_WEBHOOK_URL" >/dev/null
}

notify_slack ":warning: Starting Multipass restore: \`$SNAPSHOT_ZIP\`"

/usr/bin/echo "Creating restore directory..."
/usr/bin/mkdir -p "$RESTORE_DIR" || {
  /usr/bin/echo "Error: Could not create directory $RESTORE_DIR"
  exit 1
}

/usr/bin/echo "Fetching list of available backup files from S3..."
FILES=$(AWS_CONFIG_FILE=/home/backupuser/.aws/config \
AWS_SHARED_CREDENTIALS_FILE=/home/backupuser/.aws/credentials \
/usr/local/bin/aws --profile backup-aws-profile s3 ls "s3://$S3_BUCKET/" | /usr/bin/awk '{print $4}' | /usr/bin/grep '\.zip$')

if [ -z "$FILES" ]; then
  /usr/bin/echo "No snapshot zip files found in S3 bucket $S3_BUCKET."
  exit 1
fi

/usr/bin/echo ""
/usr/bin/echo "Available snapshots:"
select SNAPSHOT_ZIP in $FILES; do
  if [ -n "$SNAPSHOT_ZIP" ]; then
    /usr/bin/echo "Selected snapshot: $SNAPSHOT_ZIP"
    break
  else
    /usr/bin/echo "Invalid selection. Please try again."
  fi
done

/usr/bin/echo "Downloading snapshot \`$SNAPSHOT_ZIP\` from S3..."
AWS_CONFIG_FILE=/home/backupuser/.aws/config \
AWS_SHARED_CREDENTIALS_FILE=/home/backupuser/.aws/credentials \
/usr/local/bin/aws --profile backup-aws-profile s3 cp "s3://$S3_BUCKET/$SNAPSHOT_ZIP" "$RESTORE_DIR/"

if [ $? -ne 0 ]; then
  /usr/bin/echo "Error: Failed to download snapshot from S3"
  notify_slack ":x: Restore failed: could not download snapshot \`$SNAPSHOT_ZIP\`"
  exit 1
fi

/usr/bin/echo "Stopping HAProxy..."
/usr/bin/systemctl stop haproxy.service
if [ $? -eq 0 ]; then
  /usr/bin/echo "HAProxy successfully stopped"
else
  /usr/bin/echo "Warning: Could not stop HAProxy"
fi

check_haproxy_state

/usr/bin/echo "Stopping all Multipass VMs..."
/snap/bin/multipass stop --all
if [ $? -eq 0 ]; then
  /usr/bin/echo "All VMs stopped"
else
  /usr/bin/echo "Warning: Could not stop VMs (no VMs running or other issue)"
fi

check_vms_state

/usr/bin/echo "Importing snapshot..."
/usr/bin/snap import-snapshot "$RESTORE_DIR/$SNAPSHOT_ZIP"
if [ $? -ne 0 ]; then
  /usr/bin/echo "Error: Failed to import snapshot"
  notify_slack ":x: Restore failed: could not import snapshot"
  exit 1
fi

/usr/bin/echo "Finding latest snapshot ID for 'multipass'..."
SNAPSHOT_ID=$(/usr/bin/snap saved | /usr/bin/awk '/^ID/ {next} $2 == "multipass" {print $1}' | /usr/bin/sort -n | /usr/bin/tail -n 1)

if [ -z "$SNAPSHOT_ID" ]; then
  /usr/bin/echo "Error: Could not determine snapshot ID"
  notify_slack ":x: Restore failed: could not determine snapshot ID"
  exit 1
fi

/usr/bin/echo "Restoring Multipass from snapshot ID $SNAPSHOT_ID..."
/usr/bin/snap restore "$SNAPSHOT_ID"

/usr/bin/echo "Starting all Multipass VMs..."
/snap/bin/multipass start --all
if [ $? -eq 0 ]; then
  /usr/bin/echo "All VMs started"
else
  /usr/bin/echo "Warning: Could not start VMs (no VMs exist or other issue)"
fi

check_vms_state

/usr/bin/echo "Starting HAProxy..."
systemctl start haproxy.service
if [ $? -eq 0 ]; then
  /usr/bin/echo "HAProxy successfully started"
else
  /usr/bin/echo "Warning: Could not start HAProxy"
fi

check_haproxy_state

/usr/bin/echo "Cleaning up restore file..."
/usr/bin/rm -f "$RESTORE_DIR/$SNAPSHOT_ZIP"

notify_slack ":white_check_mark: Multipass restore completed: \`$SNAPSHOT_ZIP\`"
/usr/bin/echo "Restore completed successfully."
