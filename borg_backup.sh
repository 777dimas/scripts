#!/bin/sh

MYSQLPASS=$(cat /etc/.my_pass)
BACKUPDIR=$(curl ipinfo.io/ip)

NGINXETC="/etc/nginx"
APACHEETC="/etc/httpd"
HOMEDIR="/home2/var/www"
MYSQL="/home/bak/mysql"

echo mount backup storage ...
sudo sshfs -o IdentityFile=/home/bak/.ssh/id_rsa user_name@1.1.1.1:/path/to/backup/folder /home/bak/backup -o reconnect && \

echo backup mysql ...
mkdir -p $MYSQL
for i in `mysql -uroot -p$MYSQLPASS -e'show databases;' | grep -v information_schema | grep -v Database`; do mysqldump -uroot -p$MYSQLPASS --skip-lock-tables $i > $MYSQL/$i.sql;done

echo borg_backup ...
sudo borg create --stats --list --compression zstd /home/bak/backup/$BACKUPDIR::"{now:%Y-%m-%d_%H:%M:%S}" $NGINXETC $APACHEETC $HOMEDIR $MYSQL

echo borg prune ...
#keep all archive in the last 2 month and an end of month archive for every month
sudo borg prune -v --list --keep-within=2m --keep-monthly=-1 /home/bak/backup/$BACKUPDIR

echo remove $MYSQL/*
sudo rm -rf $MYSQL

echo umount backup storage ...
sudo umount /home/bak/backup

echo FINISH!

