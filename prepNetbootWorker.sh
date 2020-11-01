#!/usr/bin/env bash
################################################################################
# Script name: prepNetbootWorker.sh
# Author: Marco Tijbout - CrossCloud.Guru
# License: GNU GPL v2.0
# Version: 1.0
#
# Usage:
#   This script needs to be executed on the Raspberry Pi itself.
################################################################################

##
## Worker Configuration
##

################################################################################
## General operations

## Update and upgrade the rPI
sudo apt update && sudo apt -y full-upgrade

################################################################################
## Script Functions. Goes before the Script Logic

collectPIDetails() {
    ## Collect system information and store in a file
    cat /proc/cpuinfo | grep Model > hardwareInfo.txt
    cat /proc/cpuinfo | grep Serial >> hardwareInfo.txt
    cat /proc/cpuinfo | grep Hardware >> hardwareInfo.txt
    cat /proc/cpuinfo | grep Revision >> hardwareInfo.txt

    MAC_ETH=$(cat /sys/class/net/eth0/address)
    echo "MAC eth0        : $MAC_ETH" >> hardwareInfo.txt

    # Convert the MAC address to a string consumable by the TFTP boot process
    MAC_ETH1="$(tr ":" - <<<$MAC_ETH)"
    echo "MAC eth0 (TFTP) : $MAC_ETH1" >> hardwareInfo.txt

    MAC_WLN=$(cat /sys/class/net/wlan0/address)
    echo "MAC wlan0       : $MAC_WLN" >> hardwareInfo.txt

    SERIALNR=$(cat /proc/cpuinfo | grep Serial)
    echo "Netboot serial  : ${SERIALNR:(-8)}" >> hardwareInfo.txt

    cat hardwareInfo.txt
}

preparePI3Bp() {
    ## Configuring the Raspberry Pi 3 Model B Plus for PXE booting

    # Check if Pi is already configured
    OTP_VALUE=$(vcgencmd otp_dump | grep 17:)
    OTP_NETBOOT="17:3020000a"

    if  [[ ${OTP_VALUE} == ${OTP_NETBOOT} ]] ; then
        echo -e "\nThis Raspberry Pi 3B Plus is already Netboot enabled."
        exit 0
    else
        echo -e "\nPrepare the Raspberry Pi 3B Plus to enable Netboot."
        echo program_usb_boot_mode=1 | sudo tee -a /boot/config.txt
        echo -e "\nReboot required. Please reboot the Raspberry Pi"
    fi
}

preparePI4() {
    ## Configuring the Raspberry Pi 4 Model B for PXE booting

    ## Specify latest beta eeprom firmware
    PI_EEPROM_VERSION=pieeprom-2020-07-31

    # Donwload the beta eeprom firmware
    wget https://github.com/raspberrypi/rpi-eeprom/raw/master/firmware/beta/${PI_EEPROM_VERSION}.bin
    sudo rpi-eeprom-config ${PI_EEPROM_VERSION}.bin > bootconf.txt
    sed -i 's/BOOT_ORDER=.*/BOOT_ORDER=0x21/g' bootconf.txt
    sudo rpi-eeprom-config --out ${PI_EEPROM_VERSION}-netboot.bin --config bootconf.txt ${PI_EEPROM_VERSION}.bin
    sudo rpi-eeprom-update -d -f ./${PI_EEPROM_VERSION}-netboot.bin
}

################################################################################
## Script Logic

## Determine model of Raspberry Pi
CURRENT_PI=$(cat /proc/cpuinfo | grep Model)
#echo $CURRENT_PI
PI_4B="Raspberry Pi 4 Model B"
PI_3Bp="Raspberry Pi 3 Model B Plus"
PI_3B="Raspberry Pi 3 Model B Rev"

# Call function to store information about the Raspberry Pi for later consumption
collectPIDetails

# Select what to do based on type of Raspberry Pi
case $CURRENT_PI in
    *${PI_3B}* )
        echo -e "\nThis is a ${PI_3B}"
        ;;
    *${PI_3Bp}* )
        echo -e "\nThis is a ${PI_3Bp}"
        preparePI3Bp
        ;;
    *${PI_4B}* )
        echo -e "\nThis is a ${PI_4B}"
        preparePI4
        ;;
    * )
        echo -e "Raspberry Pi is not identified";;
esac
