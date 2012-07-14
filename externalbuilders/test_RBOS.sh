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


#enter users home directory
cd ~

#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/dev

#kill any process accessing the livedisk mountpoint 
fuser ~/RBOS_Build_Files/build_mountpoint -km

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint



#END PAST RUN CLEANUP##################



#mount the image as a loop device
mount ~/RBOS_Build_Files/RBOS_FS.img ~/RBOS_Build_Files/build_mountpoint -o loop,compress-force=lzo

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev ~/RBOS_Build_Files/build_mountpoint/phase_2/dev/
mount --rbind /proc ~/RBOS_Build_Files/build_mountpoint/phase_2/proc/
mount --rbind /sys ~/RBOS_Build_Files/build_mountpoint/phase_2/sys/

#allow all local connections to the xserver
xhost +LOCAL:


#tell the user how to exit chroot
echo "Type exit to go back to your system."

#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoint/phase_2

#set the xserver security back to what it should be
xhost -LOCAL:

#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/dev
 
#kill any process accessing the livedisk mountpoint 
fuser -km ~/RBOS_Build_Files/build_mountpoint/phase_2/ 

#create the subvolume that phase 2 will work with

#go back to the users home folder
cd ~

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint