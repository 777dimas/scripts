#!/bin/bash

STATUS="$(systemctl is-active openvpn@server.service)"
if [ "${STATUS}" = "active" ]; then
    sudo systemctl stop openvpn@server.service	
    echo "Stop openvpn@server.service ..."
else 
    sudo systemctl start openvpn@server.service
    echo "Start openvpn@server.service ..."  
    exit 1  
fi
