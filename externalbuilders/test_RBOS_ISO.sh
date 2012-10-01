#! /bin/bash
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

MOUNTISO=$(readlink -f $1)
MOUNTHOME=~
XALIVE=$(xprop -root>/dev/null 2>&1; echo $?)

if [[ $UID != 0 ]]
then

if [[ $XALIVE == 0 ]]
then

if [[ -f /usr/bin/kdesudo ]]
then
kdesudo $0 $MOUNTISO
elif [[ -f /usr/bin/gksudo ]]
then
gksudo $0 $MOUNTISO
else
zenity --info --text "This Needs to be run as root"
fi
else
sudo $0 $MOUNTISO
fi
exit
fi



function mountisoexit() 
{
if [[ -f $MOUNTHOME/liveisotest/unionmountpoint/online ]]
then

if [[ $XALIVE == 0 ]]
then
zenity --question --text "Do you want to leave the virtual images mounted? If you answer no, the programs you opened from the image, or programs accessing files on the image will be terminated"
unmountanswer=$?
else
dialog --stdout --yesno "Do you want to leave the virtual images mounted? If you answer no, the programs you opened from the image, or programs accessing files on the image will be terminated" 30 30
unmountanswer=$?
fi



if [ $unmountanswer -eq 1 ]
then
echo "Cleaning up..."
#set the xserver security back to what it should be
xhost -LOCAL:

#unmount the filesystems used by the CD
umount -lf  $MOUNTHOME/liveisotest/unionmountpoint/dev
umount -lf  $MOUNTHOME/liveisotest/unionmountpoint/sys
umount -lf  $MOUNTHOME/liveisotest/unionmountpoint/proc
umount -lf  $MOUNTHOME/liveisotest/unionmountpoint/tmp

fuser -kmM   $MOUNTHOME/liveisotest/unionmountpoint 2> /dev/null
umount -lfd $MOUNTHOME/liveisotest/unionmountpoint

fuser -kmM   $MOUNTHOME/liveisotest/squashfsmount 2> /dev/null
umount -lfd $MOUNTHOME/liveisotest/squashfsmount

fuser -kmM  $MOUNTHOME/liveisotest/isomount 2> /dev/null
umount -lfd $MOUNTHOME/liveisotest/isomount


if [[ $XALIVE == 0 ]]
then
zenity --question --text "Keep Temporary overlay files?"
deleteanswer=$?
else
dialog --stdout --yesno "Keep Temporary overlay files?" 30 30
deleteanswer=$?
fi
if [ $deleteanswer -eq 1 ]
then 
rm -rf $MOUNTHOME/liveisotest/overlay
fi
fi
exit
fi
}


if [[ $XALIVE == 0 ]]
then
zenity --info --text "This will call a chroot shell from an iso. If you use an iso from RebeccaBlackLinux you can call test Wayland by running westoncaller from the shell.

The password for the test user is no password. Just hit enter if you actually need it."
else
echo "This will call a chroot shell from an iso. If you use an iso from RebeccaBlackLinux you can call test Wayland by running westoncaller from the shell.

The password for the test user is no password. Just hit enter if you actually need it.

Press enter"
read a
fi




#enter users home directory
cd $MOUNTHOME

mountpoint $MOUNTHOME/liveisotest/unionmountpoint
ismount=$?
if [ $ismount -eq 0 ]
then


if [[ $XALIVE == 0 ]]
then
zenity --info --text "A script is running that is already testing an ISO. will now chroot into it"
xterm -e chroot $MOUNTHOME/liveisotest/unionmountpoint su livetest
else
echo "A script is running that is already testing an ISO. will now chroot into it"
echo "Type exit to go back to your system."
chroot $MOUNTHOME/liveisotest/unionmountpoint su livetest
fi
mountisoexit
fi

#install needed tools to allow testing on a read only iso
if [[ $XALIVE == 0 ]]
then
if [[ ! -f $(which xterm) ]]
then
zenity --question --text "xterm is needed for this script. Install xterm?"  
xterminstall=$?
if [[ $xterminstall -eq 0 ]]
then 
pkcon install xterm -y
else
zenity --info --text "Can not continue without xterm. Exiting the script."
exit
fi
fi
xterm -e pkcon install unionfs-fuse
xterm -e pkcon install squashfs-tools
xterm -e pkcon install dialog
xterm -e pkcon install zenity
else
pkcon install unionfs-fuse
pkcon install squashfs-tools
pkcon install dialog
pkcon install zenity
pkcon install xterm
fi

#make the folders for mounting the ISO
mkdir -p $MOUNTHOME/liveisotest/isomount
mkdir -p $MOUNTHOME/liveisotest/squashfsmount
mkdir -p $MOUNTHOME/liveisotest/overlay
mkdir -p $MOUNTHOME/liveisotest/unionmountpoint


#if there is no iso specified 
if [ -z $MOUNTISO ]
then 

if [[ $XALIVE == 0 ]]
then
zenity --info --text "No ISO specified as an argument. Please select one in the next dialog."
MOUNTISO=$(zenity --file-selection)
else
echo "


Please specify a path to an ISO as an argument to this script (with quotes around the path if there are spaces in it)"
exit
fi
fi

#mount the ISO
mount -o loop "$MOUNTISO" $MOUNTHOME/liveisotest/isomount


#if the iso doesn't have a squashfs image
if [ ! -f $MOUNTHOME/liveisotest/isomount/casper/filesystem.squashfs  ]
then
if [[ $XALIVE == 0 ]]
then
zenity --info --text "Invalid CDROM image. Not an Ubuntu based image. Exiting and unmounting the image."
else
echo "Invalid CDROM image. Not an Ubuntu based image. Press enter."
read a 
fi
#unmount and exit
umount $MOUNTHOME/liveisotest/isomount
exit
fi

#mount the squashfs image
mount -o loop $MOUNTHOME/liveisotest/isomount/casper/filesystem.squashfs $MOUNTHOME/liveisotest/squashfsmount

#Create the union between squashfs and the overlay
unionfs-fuse -o cow,use_ino,suid,dev,default_permissions,allow_other,nonempty,max_files=131068 $MOUNTHOME/liveisotest/overlay=RW:$MOUNTHOME/liveisotest/squashfsmount $MOUNTHOME/liveisotest/unionmountpoint

#bind mount in the critical filesystems
mount --rbind /dev $MOUNTHOME/liveisotest/unionmountpoint/dev
mount --rbind /proc $MOUNTHOME/liveisotest/unionmountpoint/proc
mount --rbind /sys $MOUNTHOME/liveisotest/unionmountpoint/sys
mount --rbind /tmp $MOUNTHOME/liveisotest/unionmountpoint/tmp

#allow all local connections to the xserver
xhost +LOCAL:


#tell the user how to exit chroot
if [[ $XALIVE == 0 ]]
then
zenity --info --text "Type exit into the terminal window that will come up after this dialog when you want to unmount the ISO image"
else
echo "
Type exit to go back to your system. If you want to test wayland, run the command: westoncaller"
fi

#Configure test system
cp /etc/resolv.conf $MOUNTHOME/liveisotest/unionmountpoint/etc
chroot $MOUNTHOME/liveisotest/unionmountpoint groupadd -r admin 
chroot $MOUNTHOME/liveisotest/unionmountpoint /usr/sbin/useradd -m -p "\$1\$LmxKgiWh\$XJQxuFvmcfFoFpPTVlboC1" -s /bin/bash -G admin,plugdev -u 999999999 livetest 

touch $MOUNTHOME/liveisotest/unionmountpoint/online
if [[ $XALIVE == 0 ]]
then
xterm -e chroot $MOUNTHOME/liveisotest/unionmountpoint su livetest
else
chroot $MOUNTHOME/liveisotest/unionmountpoint su livetest
fi

#go back to the users home folder
cd $MOUNTHOME


mountisoexit
