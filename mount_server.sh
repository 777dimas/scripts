#!/bin/bash

if ping -i 0.2 -c 2 192.168.88.77
then
sshfs user@192.168.88.77:/mnt/Data /home/user/media_server/
fi

