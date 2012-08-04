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
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/dev

#Kill processess accessing the workdir mountpoint
fuser -kmM   ~/RBOS_Build_Files/build_mountpoints/workdir 2> /dev/null

#unmount the FS at the workdir
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir



#END PAST RUN CLEANUP##################



#mount the image as a loop device
mount ~/RBOS_Build_Files/RBOS_FS_PHASE_1.img ~/RBOS_Build_Files/build_mountpoints/phase_1 -o loop

#call the manager script for resizing the disk image 
$ThIsScriPtSFolDerLoCaTion/externalbuilders/fsresizer "~/RBOS_Build_Files/RBOS_FS_PHASE_1.img" & >> ~/RBOS_Build_Files/fsresizer.log

#bind mount the FS to the workdir
mount --bind ~/RBOS_Build_Files/build_mountpoints/phase_1 ~/RBOS_Build_Files/build_mountpoints/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev ~/RBOS_Build_Files/build_mountpoints/workdir/dev/
mount --rbind /proc ~/RBOS_Build_Files/build_mountpoints/workdir/proc/
mount --rbind /sys ~/RBOS_Build_Files/build_mountpoints/workdir/sys/

#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr ~/RBOS_Build_Files/build_mountpoints/workdir/temp/


#make the imported files executable 
chmod +x -R ~/RBOS_Build_Files/build_mountpoints/workdir/temp/
chown  root  -R ~/RBOS_Build_Files/build_mountpoints/workdir/temp/
chgrp  root  -R ~/RBOS_Build_Files/build_mountpoints/workdir/temp/

#copy the ONLY minimal build files in, not any data files like wallpapers.
mkdir -p ~/RBOS_Build_Files/build_mountpoints/workdir/usr/bin/Compile/
cp -a ~/RBOS_Build_Files/build_mountpoints/workdir/temp/tmp/* ~/RBOS_Build_Files/build_mountpoints/workdir/tmp
cp -a ~/RBOS_Build_Files/build_mountpoints/workdir/temp/usr/bin/Compile/* ~/RBOS_Build_Files/build_mountpoints/workdir/usr/bin/Compile/
cp ~/RBOS_Build_Files/build_mountpoints/workdir/temp/usr/bin/compile_all ~/RBOS_Build_Files/build_mountpoints/workdir/usr/bin/compile_all 
cp ~/RBOS_Build_Files/build_mountpoints/workdir/temp/etc/apt/sources.list ~/RBOS_Build_Files/build_mountpoints/workdir/etc/apt/sources.list 

#delete the temp folder
rm -rf ~/RBOS_Build_Files/build_mountpoints/workdir/temp/



#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoints/workdir /tmp/configure_phase1.sh


#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/sys

#Kill processess accessing the workdir mountpoint
fuser -kmM   ~/RBOS_Build_Files/build_mountpoints/workdir 2> /dev/null

#unmount the FS at the workdir
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the underlay filesystem
umount -lfd ~/RBOS_Build_Files/build_mountpoints/phase_1

#go back to the users home folder
cd ~
