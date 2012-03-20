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

####CLEAN UP OLD SCRIPT FILES
#enter users home directory
cd ~

#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/sys

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev/pts

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev

#kill any process accessing the livedisk mountpoint 
fuser ~/RBOS_Build_Files/build_mountpoint/phase_1/ -k

#unmount the chroot fs
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1

#remove the RBOS_Build_Files folder 
rm -rf ~/RBOS_Build_Files




#END PAST RUN CLEANUP##################





#mount the image as a loop device
mount ~/RBOS_Build_Files/RBOS_FS.img ~/RBOS_Build_Files/build_mountpoint -o loop,compress-force=lzo

#mounting devfs on chrooted fs with bind 
mount --bind /dev ~/RBOS_Build_Files/build_mountpoint/phase_1/dev/

#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoint/phase_1 /tmp/configure_phase1.sh


#create the subvolume that phase 2 will work with
btrfs subvolume snapshot ~/RBOS_Build_Files/build_mountpoint/phase_1 ~/RBOS_Build_Files/build_mountpoint/phase_2


#go back to the users home folder
cd ~


#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/sys

#unmount the chrooted dev/pts from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev/pts

#unmount the chrooted dev/shm from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev/shm

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev

#kill any process accessing the livedisk mountpoint 
fuser -k ~/RBOS_Build_Files/build_mountpoint/phase_1/ 

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint/phase_1