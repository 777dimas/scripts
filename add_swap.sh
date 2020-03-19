#!/bin/sh
# add swap 1Gb
dd if=/dev/zero of=/swapfile bs=1M count=1024
mkswap /swapfile
chmod 600 /swapfile
sed -i -e "\$a/swapfile swap swap    0   0" /etc/fstab
mount -a
swapon -a
swapon -s
free -m
