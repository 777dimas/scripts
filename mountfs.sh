sudo mkdir -p "/Users/db/$1"
sudo etx4fuse "/dev/$1" "/Users/db/$1" -o allow_other
open "/Users/db/$1"
