#!/bin/bash
set -x
#notify-send "Start backup...       " --icon=dialog-information
sudo -u user DISPLAY=:0 notify-send "Start backup...       " --icon=dialog-information

rpm -qa | sort | sed -e 's/\([^.]*\).*/\1/' -e 's/\(.*\)-.*/\1/' > /home/user/Documents/list_installed_package.txt

set -o nounset -o errexit
cd $(dirname "$0")
date=$(date --iso-8601=seconds)
test -L latest || ln -s "$date" latest
rsync --delete-excluded --prune-empty-dirs --archive -F --link-dest=../latest "$@" "./$date"
rm latest
ln -s "$date" latest
#notify-send "Backup finished!!!    " --icon=dialog-information
sudo -u user DISPLAY=:0 notify-send "Backup finished!!!    " --icon=dialog-information
