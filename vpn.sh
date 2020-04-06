#!/bin/bash

STATUS="$(systemctl is-active openvpn@server.service)"
if [ "${STATUS}" = "active" ]; then
    sudo systemctl stop openvpn@server.service	
    echo "Stop openvpn@server.service ..."
    sleep 3 
    curl ipinfo.io/ip
else 
    sudo systemctl start openvpn@server.service
    echo "Start openvpn@server.service ..."
    sleep 3
    curl ipinfo.io/ip  
    exit 1  
fi
