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
echo "PHASE 0"
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

####CLEAN UP OLD SCRIPT FILES
#enter users home directory
cd ~

#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev

#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/dev

#kill any process accessing the livedisk mountpoint 
fuser ~/RBOS_Build_Files/build_mountpoint/ -km

#unmount the chroot fs
umount -lf ~/RBOS_Build_Files/build_mountpoint

#remove the RBOS_Build_Files folder 
rm -rf ~/RBOS_Build_Files




#END PAST RUN CLEANUP##################


#make a folder containing the live cd tools in the users local folder
mkdir ~/RBOS_Build_Files

#switch to that folder
cd ~/RBOS_Build_Files


#create the file that will be the filesystem image
dd if=/dev/zero of=~/RBOS_Build_Files/RBOS_FS.img bs=1 count=0 seek=16G 



echo "creating a file system on the virtual image. Not on your real file system."
#create a file system on the image 
yes y | mkfs.btrfs ~/RBOS_Build_Files/RBOS_FS.img



#create a media mountpoint in the media folder
mkdir ~/RBOS_Build_Files/build_mountpoint

#mount the image created above at the mountpoint as a loop device
mount ~/RBOS_Build_Files/RBOS_FS.img ~/RBOS_Build_Files/build_mountpoint -o loop,compress-force=lzo

#make a subvolume for the phase 1 system
btrfs subvolume create ~/RBOS_Build_Files/build_mountpoint/phase_1/

#install a really basic Ubuntu installation in the new fs  
debootstrap precise ~/RBOS_Build_Files/build_mountpoint/phase_1 http://ubuntu.osuosl.org/ubuntu/

#tell future calls of the first builder script that phase 1 is done
touch ~/RBOS_Build_Files/DontStartFromScratch

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
fuser -km ~/RBOS_Build_Files/build_mountpoint

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint