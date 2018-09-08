
#!/bin/bash

BACKUPHOST="user@1.1.1.1"
RBACKUPDIR="/path/to/backup/folder/"

#Change mysqlpass
MYSQLPASS=$(cat /etc/.my_pass)

FULLBACKUPDIR=$(curl ipinfo.io/ip)
NGINXETC="/etc/nginx/"
APACHEETC="/etc/httpd/"
HOMEDIR="/home2/var/www/"
MYSQL="/home/bak/mysql/"

HARDLINKDIR="/home/bak/hardlink/"
ORIGINALNGINXETC="/home/bak/hardlink/nginx/"
ORIGINALAPACHEETC="/home/bak/hardlink/httpd/"
ORIGINALHOME="/home/bak/hardlink/www/"

NAMENGINX=etc-nginx-$(date +%H-%M-%d%m%Y).tar.gz
NAMEAPACHE=etc-apache-$(date +%H-%M-%d%m%Y).tar.gz
NAMEHOME=home-$(date +%H-%M-%d%m%Y).tar.gz
NAMEMYSQL=sqldump-$(date +%H-%M-%d%m%Y).tar.gz

echo START BACKUP...

if [ ! -d "$HARDLINKDIR" ]; then
        sudo mkdir $HARDLINKDIR
        sudo cp --archive --link $NGINXETC $HARDLINKDIR
        sudo cp --archive --link $APACHEETC $HARDLINKDIR
        sudo cp --archive --link $HOMEDIR $HARDLINKDIR
fi

mkdir -p /home/bak/$FULLBACKUPDIR/$(date +%H-%M-%d%m%Y)
TEMP1=/home/bak/$FULLBACKUPDIR
TEMP2=$(date +%H-%M-%d%m%Y)

RSYNC_COMMAND1=$(sudo rsync -aEi --dry-run --delete $NGINXETC $ORIGINALNGINXETC)
        if [ $? -eq 0 ]; then
                if [ -n "${RSYNC_COMMAND1}" ]; then
            # Stuff to run, because rsync has changes
                echo RUN!
                echo tar $NGINXETC ...
                sudo tar -zcPf $TEMP1/$TEMP2/$NAMENGINX $NGINXETC
                sudo rm -rf $ORIGINALNGINXETC
                sudo cp --archive --link $NGINXETC $HARDLINKDIR
                echo DONE

                else
                echo NO RUN!
            # No changes were made by rsync
                fi
        else
        echo OPS!!!..
                exit 1
        fi

RSYNC_COMMAND2=$(sudo rsync -aEi --dry-run --delete $APACHEETC $ORIGINALAPACHEETC)
        if [ $? -eq 0 ]; then
                if [ -n "${RSYNC_COMMAND2}" ]; then
            # Stuff to run, because rsync has changes
                echo RUN!
                echo tar $APACHEETC ...
                sudo tar -zcPf $TEMP1/$TEMP2/$NAMEAPACHE $APACHEETC
                sudo rm -rf $ORIGINALAPACHEETC
                sudo cp --archive --link $APACHEETC $HARDLINKDIR
                echo DONE

                else
                echo NO RUN!
            # No changes were made by rsync
                fi
        else
        echo OPS!!!..
                exit 1
        fi

RSYNC_COMMAND3=$(sudo rsync -aEi --dry-run --delete $HOMEDIR $ORIGINALHOME)
        if [ $? -eq 0 ]; then
                if [ -n "${RSYNC_COMMAND3}" ]; then
            # Stuff to run, because rsync has changes
                echo RUN!
                echo tar $HOMEDIR ...
                sudo tar -zcPf $TEMP1/$TEMP2/$NAMEHOME $HOMEDIR
                sudo rm -rf $ORIGINALHOME
                sudo cp --archive --link $HOMEDIR $HARDLINKDIR
                echo DONE

                else
                echo NO RUN!
            # No changes were made by rsync
                fi
        else
        echo OPS!!!..
                exit 1
        fi

echo backup mysql ...
mkdir -p /home/bak/mysql
for i in `mysql -uroot -p$MYSQLPASS -e'show databases;' | grep -v information_schema | grep -v Database`; do mysqldump -uroot -p$MYSQLPASS --skip-lock-tables $i > $MYSQL/$i.sql;done
echo tar $MYSQL ...
sudo tar -zcPf $TEMP1/$TEMP2/$NAMEMYSQL $MYSQL
echo DONE

echo rsyncing ...
sudo rsync --progress -av -e "ssh -i /path/to/.ssh/id_rsa" $TEMP1/$TEMP2 $BACKUPHOST:$RBACKUPDIR/$FULLBACKUPDIR
echo DONE

echo delete $MYSQL ...
sudo rm -rf $MYSQL
echo delete $TEMP ...
sudo rm -rf $TEMP1

echo FINISH!!!


