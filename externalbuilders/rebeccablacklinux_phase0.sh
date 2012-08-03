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
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/dev

#Kill processess accessing the workdir mountpoint
fuser -kmM   ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the FS at the workdir
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the underlay filesystem
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir/phase_1

#remove the RBOS_FS images
rm  ~/RBOS_Build_Files/*.img




#END PAST RUN CLEANUP##################


#make a folder containing the live cd tools in the users local folder
mkdir ~/RBOS_Build_Files

#switch to that folder
cd ~/RBOS_Build_Files


#create the file that will be the filesystem image for the first phase
dd if=/dev/zero of=~/RBOS_Build_Files/RBOS_FS_PHASE_1.img bs=1 count=0 seek=8G 



echo "creating a file system on the virtual image. Not on your real file system."
#create a file system on the image 
yes y | mkfs.ext4 ~/RBOS_Build_Files/RBOS_FS_PHASE_1.img



#create a folder for the media mountpoints in the media folder
mkdir ~/RBOS_Build_Files/build_mountpoints
mkdir ~/RBOS_Build_Files/build_mountpoints/phase_1
mkdir ~/RBOS_Build_Files/build_mountpoints/phase_2
mkdir ~/RBOS_Build_Files/build_mountpoints/workdir

#mount the image created above at the mountpoint as a loop device
mount ~/RBOS_Build_Files/RBOS_FS_PHASE_1.img ~/RBOS_Build_Files/build_mountpoints/phase_1 -o loop

#bind mount the FS to the workdir
mount --bind mkdir ~/RBOS_Build_Files/build_mountpoints/phase_1 ~/RBOS_Build_Files/build_mountpoints/workdir

#install a really basic Ubuntu installation in the new fs  
debootstrap quantal ~/RBOS_Build_Files/build_mountpoints/workdir http://ubuntu.osuosl.org/ubuntu/

#tell future calls of the first builder script that phase 1 is done
touch ~/RBOS_Build_Files/DontStartFromScratch

#go back to the users home folder
cd ~


#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/dev
 
#Kill processess accessing the workdir mountpoint
fuser -kmM   ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the FS at the workdir
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the underlay filesystem
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir/phase_1