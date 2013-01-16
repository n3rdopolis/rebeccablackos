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
echo "PHASE 2"  
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

HOMELOCATION=~
RBOSLOCATION=~/RBOS_Build_Files
unset HOME

#create a folder for the media mountpoints in the media folder
mkdir $RBOSLOCATION/build_mountpoints
mkdir $RBOSLOCATION/build_mountpoints/phase_1
mkdir $RBOSLOCATION/build_mountpoints/phase_2
mkdir $RBOSLOCATION/build_mountpoints/phase_3
mkdir $RBOSLOCATION/build_mountpoints/buildoutput
mkdir $RBOSLOCATION/build_mountpoints/workdir

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the FS at the workdir and phase 2
umount -lfd $RBOSLOCATION/build_mountpoints/workdir
umount -lfd $RBOSLOCATION/build_mountpoints/phase_2

#Compare the /tmp/INSTALLS.txt file from previous builds, to the current one. If the current one has missing lines, (meaning that a package should not be installed) then reset phase 2.
INSTALLREMOVECOUNT="$(diff -uN $RBOSLOCATION/build_mountpoints/phase_2/tmp/INSTALLS.txt.bak $ThIsScriPtSFolDerLoCaTion/../rebeccablacklinux_files/tmp/INSTALLS.txt | grep ^- | grep -v "\---" | wc -l)"
if [[ $INSTALLREMOVECOUNT -gt 0 || ! -f $RBOSLOCATION/DontRestartPhase2 ]]
then
#Delete the phase 2 folder contents
rm -rf $RBOSLOCATION/build_mountpoints/phase_2/*
touch $RBOSLOCATION/DontRestartPhase2
fi

#create the union of phases 1 and 2 at the workdir
mount -t overlayfs -o lowerdir=$RBOSLOCATION/build_mountpoints/phase_1,upperdir=$RBOSLOCATION/build_mountpoints/phase_2 overlayfs $RBOSLOCATION/build_mountpoints/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $RBOSLOCATION/build_mountpoints/workdir/dev/
mount --rbind /proc $RBOSLOCATION/build_mountpoints/workdir/proc/
mount --rbind /sys $RBOSLOCATION/build_mountpoints/workdir/sys/


#Configure the Live system########################################
chroot $RBOSLOCATION/build_mountpoints/workdir /tmp/configure_phase2.sh



#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the debs data
umount -lf $RBOSLOCATION/build_mountpoints/workdir/srcbuild/buildoutput

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build_mountpoints/workdir

