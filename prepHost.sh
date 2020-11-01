#!/usr/bin/env bash
# Author: Marco Tijbout - CrossCloud.Guru
# License: GNU GPL v2.0
# Version: 1

## Enhancement Tips:
#   Acquire details from input file

##
## Server Configuration - Network Boot Server
##

# Update and upgrade the rPI
sudo apt update && sudo apt full-upgrade -y

# Create required directories
[ ! -d /tftpboot ] && mkdir -p /tftpboot
[ ! -d /nfs ] && mkdir -p /nfs

# Install required software when missing:
[ ! -x /usr/bin/unzip ] && sudo apt install -y unzip
[ ! -x /sbin/kpartx ] && sudo apt install -y kpartx
[ ! -x /usr/sbin/dnsmasq ] && sudo apt install -y dnsmasq
[ ! -x /usr/sbin/tcpdump ] && sudo apt install -y tcpdump

sudo service nfs-kernel-server status > /dev/null
STATUS=$?
if [ ${STATUS} -ne 0 ]; then
    if [ ${STATUS} -eq 3 ]; then
        echo -e "nfs-kernel-server is installed but not running"
    else
        sudo apt install -y nfs-kernel-server
    fi
fi
unset STATUS

# Enable and restart rpcbind and nfs-kernel-server services:
sudo systemctl enable nfs-kernel-server
sudo systemctl restart rpcbind
sudo systemctl restart nfs-kernel-server

# Reconfigure dnsmasq to server TFTP files only to Raspberry Pi instances as 
# described here:

echo 'dhcp-range=10.16.0.0,proxy' | sudo tee -a /etc/dnsmasq.conf
echo 'log-dhcp' | sudo tee -a /etc/dnsmasq.conf
echo 'enable-tftp' | sudo tee -a /etc/dnsmasq.conf
echo 'tftp-root=/tftpboot' | sudo tee -a /etc/dnsmasq.conf
echo 'pxe-service=0,"Raspberry Pi Boot"' | sudo tee -a /etc/dnsmasq.conf

# Enable and restart the dnsmasq service:
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq

# Watch the output of the logs while booting the Raspberry Pi
sudo tail -f /var/log/daemon.log
