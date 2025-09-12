#!/bin/bash

BACKUP_DIR="/backups/multipass/$(/usr/bin/date +%F_%H-%M-%S)"  
SNAPSHOT_ZIP="multipass-snapshot-$(/usr/bin/date +%F_%H-%M-%S).zip"
S3_BUCKET="multipass-backup"

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command '$1' is not installed or not in PATH."
    exit 1
  fi
}

echo "Checking required tools..."
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

if [ -z "$SLACK_WEBHOOK_URL" ]; then
  /usr/bin/echo "Error: SLACK_WEBHOOK_URL environment variable is not set."
  exit 1
fi

notify_slack() {
    local MESSAGE="$1"
    /usr/bin/curl -s -X POST -H 'Content-type: application/json' \
         --data "{\"text\":\"${MESSAGE}\"}" "$SLACK_WEBHOOK_URL" >/dev/null
}

notify_slack ":floppy_disk: Starting Multipass backup: $(/usr/bin/date)"

if [ "$EUID" -ne 0 ]; then
  /usr/bin/echo "Error: Script must be run with superuser privileges (sudo)."
  exit 1
fi

/usr/bin/mkdir -p "$BACKUP_DIR" || {
  /usr/bin/echo "Error: Could not create directory $BACKUP_DIR"
  exit 1
}

/usr/bin/echo "Starting Multipass backup: $(/usr/bin/date)"

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

/usr/bin/echo "Stopping snap service for multipass..."
/usr/bin/snap stop multipass

/usr/bin/echo "Creating Multipass snapshot..."
SNAP_SET=$(/usr/bin/snap save multipass | /usr/bin/grep -oP '^\d+' | /usr/bin/head -1)
if [ -z "$SNAP_SET" ]; then
  /usr/bin/echo "Error: Could not create snapshot"
  exit 1
fi
/usr/bin/echo "Snapshot #$SNAP_SET created"

/usr/bin/echo "Exporting snapshot #$SNAP_SET to $BACKUP_DIR/$SNAPSHOT_ZIP..."
/usr/bin/snap export-snapshot "$SNAP_SET" "$BACKUP_DIR/$SNAPSHOT_ZIP"
if [ $? -eq 0 ]; then
  /usr/bin/echo "Snapshot successfully exported: $BACKUP_DIR/$SNAPSHOT_ZIP"
else
  /usr/bin/echo "Error exporting snapshot"
  exit 1
fi

/usr/bin/echo "Snapshot saved to: $BACKUP_DIR/$SNAPSHOT_ZIP"

/usr/bin/echo "Starting snap service for multipass..."
/usr/bin/snap start multipass

for i in {1..30}; do
    /snap/bin/multipass list >/dev/null 2>&1 && break
    /usr/bin/echo "Waiting for Multipass to start..."
    /usr/bin/sleep 1
done

/usr/bin/echo "Starting all Multipass VMs..."
/snap/bin/multipass start --all
if [ $? -eq 0 ]; then
  /usr/bin/echo "All VMs started"
else
  /usr/bin/echo "Warning: Could not start VMs (no VMs exist or other issue)"
fi

check_vms_state

/usr/bin/echo "Starting HAProxy..."
/usr/bin/systemctl start haproxy.service
if [ $? -eq 0 ]; then
  /usr/bin/echo "HAProxy successfully started"
else
  /usr/bin/echo "Warning: Could not start HAProxy"
fi

check_haproxy_state

/usr/bin/echo "Copy $SNAPSHOT_ZIP to S3 bucket..."
AWS_CONFIG_FILE=/home/backupuser/.aws/config \
AWS_SHARED_CREDENTIALS_FILE=/home/backupuser/.aws/credentials \
/usr/local/bin/aws --profile backup-aws-profile s3 sync "$BACKUP_DIR" "s3://$S3_BUCKET/"

AWS_CONFIG_FILE=/home/backupuser/.aws/config \
AWS_SHARED_CREDENTIALS_FILE=/home/backupuser/.aws/credentials \
/usr/local/bin/aws --profile backup-aws-profile s3 ls "s3://$S3_BUCKET/"

/usr/bin/echo "Snapshot $SNAPSHOT_ZIP has been copied to S3 bucket $S3_BUCKET"

notify_slack ":white_check_mark: Backup completed: $(/usr/bin/date)\nFile: \`$SNAPSHOT_ZIP\`"

/usr/bin/echo "Backup completed: $(/usr/bin/date)"
