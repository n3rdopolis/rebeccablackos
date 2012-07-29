#! /usr/bin/sudo /bin/bash
#    Copyright (c) 2012, nerdopolis (or n3rdopolis) <bluescreen_avenger@version.net>
#
#    This file is part of RebeccaBlackLinux.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

echo "This will call a chroot shell from an iso. If you use an iso from RebeccaBlackLinux you can call test Wayland by running westoncaller from the shell.
The ISO needs to be the root of your home folder, as that's where it searches for ISOs

Press enter"

read a
#enter users home directory
cd ~


mountpoint ~/RBOS_Build_Files/isotest/unionmountpoint
ismount=$?
if [ $ismount -eq 0 ]
then
echo "A script is running that is already testing an ISO. will now chroot into it"
echo "Type exit to go back to your system."
chroot ~/RBOS_Build_Files/isotest/unionmountpoint
exit
fi

#install needed tools to allow testing on a read only iso
apt-get install aufs-tools squashfs-tools


#make a folders for mounting the ISO
mkdir -p ~/RBOS_Build_Files/isotest/isomount
mkdir -p ~/RBOS_Build_Files/isotest/squashfsmount
mkdir -p ~/RBOS_Build_Files/isotest/overlay
mkdir -p ~/RBOS_Build_Files/isotest/unionmountpoint

#Get a list of isos in the home directory
ISOS="$(ls ~ | grep .iso$ | nl -ba -w 3)"

#if there are no iso files found in the home directory exit
if [ -z $ISOS ]
then 
echo "No ISOs Found"
exit
fi

#list the isos found, and get the number of the selected iso
ISONUMBER=$(dialog --stdout --menu "menu" 30 30 30 $ISOS )

#get the name of the selected iso from the number
ISO=$(echo "$ISOS" | grep "^  $ISONUMBER" | awk '{print $2}')

#mount the ISO
mount -o loop ~/$ISO ~/RBOS_Build_Files/isotest/isomount


#if the iso doesn't have a squashfs image
if [ ! -f ~/RBOS_Build_Files/isotest/isomount/casper/filesystem.squashfs  ]
then
echo "Invalid CDROM image. Not an Ubuntu/RebeccaBlackLinux based image" 
#unmount and exit
umount ~/RBOS_Build_Files/isotest/isomount
exit
fi

#mount the squashfs image
mount -o loop ~/RBOS_Build_Files/isotest/isomount/casper/filesystem.squashfs ~/RBOS_Build_Files/isotest/squashfsmount

#Create the union between squashfs and the overlay
mount -t aufs -o dirs=~/RBOS_Build_Files/isotest/overlay:~/RBOS_Build_Files/isotest/squashfsmount none ~/RBOS_Build_Files/isotest/unionmountpoint

#bind mount in the critical filesystems
mount --rbind /dev ~/RBOS_Build_Files/isotest/unionmountpoint/dev
mount --rbind /proc ~/RBOS_Build_Files/isotest/unionmountpoint/proc
mount --rbind /sys ~/RBOS_Build_Files/isotest/unionmountpoint/sys

#allow all local connections to the xserver
xhost +LOCAL:


#tell the user how to exit chroot
echo "
Type exit to go back to your system. If you want to test wayland, run the command: westoncaller"

#Chroot into the live system
chroot ~/RBOS_Build_Files/isotest/unionmountpoint

#set the xserver security back to what it should be
xhost -LOCAL:

#go back to the users home folder
cd ~

#unmount the filesystems used by the CD
umount -lf  ~/RBOS_Build_Files/isotest/unionmountpoint/dev
umount -lf  ~/RBOS_Build_Files/isotest/unionmountpoint/sys
umount -lf  ~/RBOS_Build_Files/isotest/unionmountpoint/proc

mountpoint ~/RBOS_Build_Files/isotest/unionmountpoint
ismount=$?
if [ $ismount -eq 0 ]
then
fuser -km   ~/RBOS_Build_Files/isotest/unionmountpoint
umount -lfd ~/RBOS_Build_Files/isotest/unionmountpoint
fi

mountpoint ~/RBOS_Build_Files/isotest/squashfsmount
ismount=$?
if [ $ismount -eq 0 ]
then
fuser -km   ~/RBOS_Build_Files/isotest/squashfsmount
umount -lfd ~/RBOS_Build_Files/isotest/squashfsmount
fi

mountpoint ~/RBOS_Build_Files/isotest/isomount
ismount=$?
if [ $ismount -eq 0 ]
then
fuser -km   ~/RBOS_Build_Files/isotest/isomount
umount -lfd ~/RBOS_Build_Files/isotest/isomount
fi
