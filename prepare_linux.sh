#!/bin/bash

# Author: Jason Shuler
# Description:
# This script will prepare a UEFI dual-booted linux install for
# in-place virtualization in VirtualBox in windows on the same drive
# NOTE: Only for debian-based (apt package mgmt)
# 
# USE AT YOUR OWN RISK
# TODO: Add resilience / error checking
# TODO: Include VMWare version (using open-vm... package)
# TODO: Auto-reboot?
# TODO: Remove windows entries from GRUB?
# TODO: Create reverse (virtualize bare-metal windows in linux)


# Install prerequisites
sudo apt install -y wget curl build-essential qemu-utils

# Install VirtualBox Guest Additions
export VBOX_VER="`wget -O - -o /dev/null https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT`"
wget https://download.virtualbox.org/virtualbox/$VBOX_VER/VBoxGuestAdditions_$VBOX_VER.iso
sudo mkdir /media/VBoxGuestAdditions
sudo mount ./VBoxGuestAdditions_$VBOX_VER.iso /media/VBoxGuestAdditions -o loop
sudo /media/VBoxGuestAdditions/VBoxLinuxAdditions.run
sudo umount /media/VBoxGuestAdditions
sudo rmdir /media/VBoxGuestAdditions
rm ./VBoxGuestAdditions_$VBOX_VER.iso

# Since we are dual booting, change linux to use local time
sudo timedatectl set-local-rtc 1

# Add nofail to the efi mount point, otherwise boot may fail in VM
sudo cp /etc/fstab ./fstab.backup
# TODO: check if nofail is already there
# TODO: Can there be no options? Handle comma...
sudo sed -i --regexp-extended 's/(\/boot\/efi\s+vfat\s+)/\1nofail,/g' /etc/fstab

# Get the device name for the EFI partition from df
export EFI_DEVICE=`df | sed --regexp-extended -n 's/^([^\t ]+).+\/boot\/efi$/\1/gp'`
# TODO: error handling
# Image the efi partition
sudo dd if=$EFI_DEVICE bs=4M of=./efi.dd
# Mount the image
sudo mkdir /mnt/efitmp
sudo mount -t vfat -o loop efi.dd /mnt/efitmp
# Cleanup Microsoft EFI junk
sudo rm -rf /mnt/efitmp/'System Volume Information'
sudo rm -rf /mnt/efitmp/EFI/Microsoft

# Find and update virtual grub.cfg to skip menu
sudo find /mnt/efitmp/EFI -name grub.cfg -exec sed -i '1 i\GRUB_TIMEOUT=0' {}

# Unmount, cleanup
sudo umount /mnt/efitmp
sudo rmdir /mnt/efitmp
# Convert raw image to vmdk
qemu-img convert -O vmdk ./efi.dd ./efi.vmdk
# Cleanup raw image
sudo rm ./efi.dd
# All done!
echo Now copy efi.vmdk to a thumb drive or your windows partition.
echo You can now reboot into windows