#!/bin/bash

#Remove all previous rules
sudo iptables --flush

#Allow access to localhost
sudo iptables -A INPUT -i lo -j ACCEPT

#Allow any alredy established connection
sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

#Allow access to web port 80 and 443
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
#sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

#Allow access to rsync port 873
sudo iptables -A INPUT -p tcp --dport 873 -j ACCEPT

#Allow access to ssh port 13000
sudo iptables -A INPUT -p tcp --dport 13000 -j ACCEPT

#Allow access HTML5
#sudo iptables -A INPUT -p tcp --dport 9651 -j ACCEPT
#sudo iptables -A INPUT -p tcp --dport 9867 -j ACCEPT
#sudo iptables -A INPUT -p tcp --dport 9385 -j ACCEPT

#Allow access FTP
#sudo iptables -A INPUT -p tcp --dport 21 -j ACCEPT
#sudo iptables -A INPUT -p tcp --sport 20 -m state --state ESTABLISHED,RELATED -j ACCEPT

#Allow access with ICMP
sudo iptables -A INPUT -p icmp -j ACCEPT

#Drop all other connections
sudo iptables -A INPUT -j DROP

