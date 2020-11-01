#!/usr/bin/env bash
################################################################################
# Script name: prepWorkerImage.sh
# Author: Marco Tijbout - CrossCloud.Guru
# License: GNU GPL v2.0
# Version: 2
#
# History:
#   2 - Added check if tftp share already exists in /etc/exports
#   1 - Initial released version
#
# Usage:
#   Run this script on the PiServer that serves PXE and TFTP.
#
# Improvement ideas:
#   -
################################################################################

## Create if not exist and enter project directory:
[ ! -d ~/netBoot ] && mkdir -p ~/netBoot
cd ~/netBoot

## Collect some details for a specific Raspberry Pi to work with this configuration:
INPUT_FILE=~/nodeList
KICKSTART_IP=10.16.200.1

## Download and unzip the latest Raspbian Buster Lite image:
# Download only if newer timestamp than local file
curl -RLo latest-buster-lite.zip -z latest-buster-lite.zip \
    https://downloads.raspberrypi.org/raspios_lite_armhf_latest

# Get the name of the file in the ZIP:
FILE_IN_ZIP=$(zipinfo -1 latest-buster-lite.zip)

# Extract only if not already extracted:
if [ ! -f ${FILE_IN_ZIP} ]; then
    unzip latest-buster-lite.zip
fi

doPrepWorker() {
    # Make a directory to contain the network boot client image:
    echo -e "\nCreate NFS folder for node ..."
    sudo mkdir -p /nfs/${PI_ID}

    # Mount the Raspberry Pi OS image:
    echo -e "\nMount Raspberry Pi OS Image ..."
    # Create mount points for the image
    [ -d rootmnt ] || mkdir rootmnt
    [ -d bootmnt ] || mkdir bootmnt

    # Make the image file accessible
    sudo kpartx -a -v latest-buster-lite.img

    # Mount the partitions in the image to the mountpoints
    sudo mount /dev/mapper/loop0p2 rootmnt/
    sudo mount /dev/mapper/loop0p1 bootmnt/

    # Copy the Raspbian Buster Lite image to the network boot client image directory created above:
    echo -e "\nCopy content from root mount ..."
    sudo cp -a rootmnt/* /nfs/${PI_ID}/
    echo -e "\nCopy content from boot mount ..."
    sudo cp -a bootmnt/* /nfs/${PI_ID}/boot/
    echo -e "\nDone. Unmounting ..."
    sudo umount rootmnt
    sudo umount bootmnt

    # We need to replace the default rPI firmware files with the latest version by running the following commands:
    echo -e "\nUpdate some firmware files to enable netboot ..."

    # Remove current
    sudo rm /nfs/${PI_ID}/boot/start4.elf
    sudo rm /nfs/${PI_ID}/boot/fixup4.dat

    # Download latest
    sudo wget https://github.com/Hexxeh/rpi-firmware/raw/stable/start4.elf -P /nfs/${PI_ID}/boot/
    sudo wget https://github.com/Hexxeh/rpi-firmware/raw/stable/fixup4.dat -P /nfs/${PI_ID}/boot/
    
    # Correct permissions
    sudo chmod 755 /nfs/${PI_ID}/boot/start4.elf
    sudo chmod 755 /nfs/${PI_ID}/boot/fixup4.dat

    # Ensure the network boot client image doesn't attempt to look for filesystems on the SD Card:
    echo -e "\nRemove any SD Card mount-points ..."
    sudo sed -i /UUID/d /nfs/${PI_ID}/etc/fstab

    # Replace the boot command in the network boot client image to boot from a network share.
    echo -e "\nUpdate cmdline.txt to boot from NFS share ..."
    echo "console=serial0,115200 console=tty root=/dev/nfs nfsroot=${KICKSTART_IP}:/nfs/${PI_ID},vers=3 rw ip=dhcp rootwait elevator=deadline modprobe.blacklist=bcm2835_v4l2" | sudo tee /nfs/${PI_ID}/boot/cmdline.txt

    # Enable SSH in the network boot client image:
    echo -e "\nEnable SSH at first boot of Raspberry Pi ..."
    sudo touch /nfs/${PI_ID}/boot/ssh

    # Create a network share containing the network boot client image:
    echo -e "\nCreate NFS share for node ..."
    if [[ $(grep -L "/nfs/${PI_ID}" /etc/exports) ]]; then
        echo "/nfs/${PI_ID} *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
    fi

    # Create a TrivialFTP folder containing boot code for all network boot clients
    echo -e "\nCreate TFTP root folder ..."
    [ -d /tftpboot ] || mkdir -p /tftpboot
    [ -f /tftpboot/bootcode.bin ] || sudo cp /nfs/${PI_ID}/boot/bootcode.bin /tftpboot/bootcode.bin
    sudo chmod 777 /tftpboot

    # Create a directory for the first network boot client in the /tftpboot 
    echo -e "\nCreate TFTP boot folder for node ..."
    sudo mkdir -p /tftpboot/${PI_ID}

    # Copy the boot directory from the /nfs/${PI_ID} directory to the new directory 
    # in /tftpboot:
    echo -e "\nCopy boot content to TFTP boot folder ..."
    sudo cp -a /nfs/${PI_ID}/boot/* /tftpboot/${PI_ID}/

    ## Update the /etc/hosts file with the new name.
    echo -e "\nAssigning new computername to the Raspberry Pi image ..."
    # Modify hosts file
    if grep -Fq "127.0.1.1" /nfs/${PI_ID}/etc/hosts
    then
        ## If found, replace the line
        sudo sed -i "/127.0.1.1/c\127.0.1.1    ${PI_NAME}" /nfs/${PI_ID}/etc/hosts
    else
        ## If not found, add the line
        echo '127.0.1.1    '${PI_NAME} &>> /nfs/${PI_ID}/etc/hosts
    fi
    # Modify hostname file
    sudo sed -i "/raspberry/c\\${PI_NAME}" /nfs/${PI_ID}/etc/hostname

    # The End
    echo -e "\nDone for ${PI_ID} ${PI_NAME}"
}

## Read the input file and execute
while read line ; do
    set $line
    PI_ID=$1
    PI_NAME=$2
    echo -e "\nProcessing node:" ${PI_NAME}
    doPrepWorker ${PI_ID} ${PI_NAME}
done < "${INPUT_FILE}"
