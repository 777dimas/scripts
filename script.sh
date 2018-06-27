#!/bin/bash

SRCDIR="/home/kriptex/Scripts/"
DSTDIR="/home/kriptex/Backups/"
FILENAME=scripts_$(date +%H-%M_%d%m%Y).tar.gz 

sudo tar -zcPf $DSTDIR$FILENAME $SRCDIR

find $DSTDIR -mtime +2 -type f -delete

