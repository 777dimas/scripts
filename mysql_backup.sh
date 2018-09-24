
#!/bin/bash

BACKUPHOST="user@1.1.1.1"
RBACKUPDIR="/path/to/backup/folder/"

#Change mysqlpass
MYSQLPASS=$(cat /etc/.my_pass)

MYSQLDIR="/home/super/backup_mysql/"
MYSQLTMP="/tmp/mysql/"

NAMEMYSQL=sqldump-$(date +%H-%M-%d%m%Y).tar.gz

echo backup mysql ...
mkdir -p $MYSQLTMP
for i in `mysql -uroot -p$MYSQLPASS -e'show databases;' | grep -v information_schema | grep -v Database`; do mysqldump -uroot -p$MYSQLPASS --skip-lock-tables $i > $MYSQLTMP/$i.sql;done
echo tar $MYSQL ...
sudo tar -zcPf $MYSQLDIR/$NAMEMYSQL $MYSQLTMP
echo DONE

echo delete tmp files mysql ...
rm -rf $MYSQLTMP/*

echo rsyncing ...
sudo rsync --progress -av -e "ssh -i /path/to/.ssh/id_rsa" $MYSQLDIR $BACKUPHOST:$RBACKUPDIR --delete-after
echo DONE

#delete files older than 20 days
find $MYSQLDIR -mindepth 1 -mtime +20 -delete

echo FINISH!!!
