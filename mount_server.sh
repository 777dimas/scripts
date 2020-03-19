#!/bin/bash

if ping -i 0.2 -c 2 192.168.88.77
then
sshfs turux@192.168.88.77:/mnt/Data /home/kriptex/media_server/
fi

