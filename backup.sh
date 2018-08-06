#!/bin/bash

BACKUPHOST="test@111.111.111.111"
RBACKUPDIR="/path/to/backup/file"

#Change mysqlpass
MYSQLPASS="*********"

FULLBACKUPDIR=$(hostname -I | awk '{print $1}')
NGINXETC="/etc/nginx"
APACHEETC="/etc/httpd"
HOMEDIR="/home2/var/www"
MYSQL="/home/bak/mysql"

NAMENGINX=etc-nginx-$(date +%H-%M-%d%m%Y).tar.gz
NAMEAPACHE=etc-apache-$(date +%H-%M-%d%m%Y).tar.gz
NAMEHOME=home-$(date +%H-%M-%d%m%Y).tar.gz
NAMEMYSQL=sqldump-$(date +%H-%M-%d%m%Y).tar.gz

echo START BACKUP...
mkdir -p /home/bak/$FULLBACKUPDIR-$(date +%H-%M-%d%m%Y)
TEMP=/home/bak/$FULLBACKUPDIR-$(date +%H-%M-%d%m%Y)
echo tar $NGINXETC ...
sudo tar -zcPf $TEMP/$NAMENGINX $NGINXETC
echo DONE

echo tar $APACHEETC ...
sudo tar -zcPf $TEMP/$NAMEAPACHE $APACHEETC
echo DONE

echo tar $HOMEDIR ...
sudo tar -zcPf $TEMP/$NAMEHOME $HOMEDIR
echo DONE

echo backup mysql ...
mkdir -p /home/bak/mysql
for i in `mysql -uroot -p$MYSQLPASS -e'show databases;' | grep -v information_schema | grep -v Database`; do mysqldump -uroot -p$MYSQLPASS --skip-lock-tables $i > $MYSQL/$i.sql;done
echo tar $MYSQL ...
sudo tar -zcPf $TEMP/$NAMEMYSQL $MYSQL
echo DONE

echo rsyncing ...
sudo rsync --progress -av -e "ssh -i .ssh/id_rsa" $TEMP $BACKUPHOST:$RBACKUPDIR
echo DONE

echo delete $MYSQL ...
sudo rm -rf $MYSQL
echo delete $TEMP ...
sudo rm -rf $TEMP

echo FINISH!!!

