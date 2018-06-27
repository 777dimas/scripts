#!/bin/bash

SRCDIR="/root/ftp"
DSTDIR="/root/backup/ftp/"
FILENAME=ftp_$(date +%H-%M_%d%m%Y).tar.gz 

sudo tar -zcPf $DSTDIR$FILENAME $SRCDIR

find $DSTDIR -mtime +2 -type f -delete

