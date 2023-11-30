#!/usr/bin/env python3

import subprocess
import os
import sys
import time
from vars import *

DATE_FILE = "/Users/db/tmp/backup_date"
LOCK_FILE = "/tmp/backup_lock"
MAX_BACKUPS = 5
SSH_PRIVATE_KEY = ssh_key_var
USERNAME = remote_user_var
REMOTE_HOST = remote_host_var
current_date = time.strftime('%Y%m%d')

def backup_already_done():
    try:
        with open(DATE_FILE, 'r') as file:
            last_backup_date = file.read().strip()
            return last_backup_date == current_date
    except FileNotFoundError:
        return False
    
def is_host_up(host):
    try:
        subprocess.check_output(["ping", "-c", "1", host])
        return True
    except subprocess.CalledProcessError:
        return False
    
def update_date_file():
    with open(DATE_FILE, 'w') as file:
        file.write(current_date)

def acquire_lock():
    try:
        os.open(LOCK_FILE, os.O_CREAT | os.O_EXCL | os.O_RDWR)
        return True
    except FileExistsError:
        return False

def release_lock():
    os.unlink(LOCK_FILE)

def send_notification(message, title="Backup"):
    os.system(f"osascript -e 'display notification \"{message}\" with title \"{title}\"'")

def cleanup_old_backups(remote_backup_path):
    try:
        backup_dates = sorted([name for name in subprocess.run(['ssh', '-i', ssh_key_var , f'{remote_user_var}@{remote_host_var}', f'ls {remote_directory_var}'], capture_output=True, text=True).stdout.split()])
        while len(backup_dates) > MAX_BACKUPS:
            oldest_backup = backup_dates.pop(0)
            subprocess.run(['ssh', '-i', SSH_PRIVATE_KEY, f'{USERNAME}@{REMOTE_HOST}', f'rm -rf {remote_backup_path}/{oldest_backup}'])
    except Exception as e:
        print(f"Error during cleanup: {e}")

def main():

    local_source_path = local_source_path_var
    remote_backup_path = remote_directory_var
    excluded_folder1 = "/Applications"
    excluded_folder2 = "/Library"
    excluded_folder3 = "/.wine"

    if backup_already_done():
        print("Backup for today already done. Exiting.")
        sys.exit(0)

    if not is_host_up(REMOTE_HOST):
        print(f"{REMOTE_HOST} is unreachable.")
        sys.exit(0)

    if not acquire_lock():
        print("Backup is already in progress. Exiting.")
        sys.exit(0)

    try:
        subprocess.run(['ssh', '-i', SSH_PRIVATE_KEY, f'{USERNAME}@{REMOTE_HOST}', f'mkdir {remote_backup_path}/{date}'])
    except Exception as e:
        send_notification(f"Error during creating backup folder: {e}", "Backup")
        release_lock()
        sys.exit(0)

    date = time.strftime('%Y-%m-%d_%H:%M')
    send_notification(f"Has been started at {date}", "Backup")

    try:
        subprocess.run(['rsync', '-av', '--exclude', excluded_folder1, '--exclude', excluded_folder2, '--exclude', excluded_folder3, '-e', f'ssh -i {SSH_PRIVATE_KEY}', local_source_path, f'{USERNAME}@{REMOTE_HOST}:{remote_backup_path}/{date}'])
    except Exception as e:
        send_notification(f"Error during rsync: {e}", "Backup")
        release_lock()
        sys.exit(0)

    cleanup_old_backups(remote_backup_path)
    update_date_file()
    release_lock()
    date_end = time.strftime('%Y-%m-%d_%H:%M')
    send_notification(f"Has been finished at {date_end}", "Backup")

if __name__ == "__main__":
    main()