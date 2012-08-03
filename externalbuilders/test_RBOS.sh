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
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/dev

#Kill processess accessing the workdir mountpoint
fuser -kmM   ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the FS at the workdir
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir



#END PAST RUN CLEANUP##################



#mount the image as a loop device
mount ~/RBOS_Build_Files/RBOS_FS.img ~/RBOS_Build_Files/build_mountpoints -o loop,compress-force=lzo

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev ~/RBOS_Build_Files/build_mountpoints/workdir/dev/
mount --rbind /proc ~/RBOS_Build_Files/build_mountpoints/workdir/proc/
mount --rbind /sys ~/RBOS_Build_Files/build_mountpoints/workdir/sys/

#allow all local connections to the xserver
xhost +LOCAL:


#tell the user how to exit chroot
echo "Type exit to go back to your system."

#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoints/workdir

#set the xserver security back to what it should be
xhost -LOCAL:

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


cd ~