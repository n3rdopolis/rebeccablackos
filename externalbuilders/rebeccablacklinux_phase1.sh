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
echo "PHASE 1"
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")


#enter users home directory
cd ~

#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev

#kill any process accessing the livedisk mountpoint 
fuser ~/RBOS_Build_Files/build_mountpoint -km

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint



#END PAST RUN CLEANUP##################



#mount the image as a loop device
mount ~/RBOS_Build_Files/RBOS_FS.img ~/RBOS_Build_Files/build_mountpoint -o loop,compress-force=lzo

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev ~/RBOS_Build_Files/build_mountpoint/phase_1/dev/
mount --rbind /proc ~/RBOS_Build_Files/build_mountpoint/phase_1/proc/
mount --rbind /sys ~/RBOS_Build_Files/build_mountpoint/phase_1/sys/

#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/


#make the imported files executable 
chmod +x -R ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/
chown  root  -R ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/
chgrp  root  -R ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/

#copy the ONLY minimal build files in, not any data files like wallpapers.
mkdir -p ~/RBOS_Build_Files/build_mountpoint/phase_1/usr/bin/Compile/
cp -a ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/tmp/* ~/RBOS_Build_Files/build_mountpoint/phase_1/tmp
cp -a ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/usr/bin/Compile/* ~/RBOS_Build_Files/build_mountpoint/phase_1/usr/bin/Compile/
cp ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/usr/bin/compile_all ~/RBOS_Build_Files/build_mountpoint/phase_1/usr/bin/compile_all 
cp ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/etc/apt/sources.list ~/RBOS_Build_Files/build_mountpoint/phase_1/etc/apt/sources.list 

#delete the temp folder
rm -rf ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/



#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoint/phase_1 /tmp/configure_phase1.sh


#create the subvolume that phase 2 will work with
btrfs subvolume delete ~/RBOS_Build_Files/build_mountpoint/phase_2
btrfs subvolume snapshot ~/RBOS_Build_Files/build_mountpoint/phase_1 ~/RBOS_Build_Files/build_mountpoint/phase_2

#go back to the users home folder
cd ~


#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_1/dev

#kill any process accessing the livedisk mountpoint 
fuser -km ~/RBOS_Build_Files/build_mountpoint/phase_1/ 

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint/phase_1