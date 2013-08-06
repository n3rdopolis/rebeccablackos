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
echo "PHASE 2"  
SCRIPTFILEPATH=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$SCRIPTFILEPATH")

HOMELOCATION=~
RBOSLOCATION=~/RBOS_Build_Files
unset HOME

if [[ -z $BUILDARCH ]]
then
echo "BUILDARCH variable not set"
exit
fi

#create a folder for the media mountpoints in the media folder
mkdir $RBOSLOCATION/build/$BUILDARCH
mkdir $RBOSLOCATION/build/$BUILDARCH/phase_1
mkdir $RBOSLOCATION/build/$BUILDARCH/phase_2
mkdir $RBOSLOCATION/build/$BUILDARCH/phase_3
mkdir $RBOSLOCATION/build/$BUILDARCH/buildoutput
mkdir $RBOSLOCATION/build/$BUILDARCH/workdir

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/dev

#unmount the FS at the workdir and phase 2
umount -lfd $RBOSLOCATION/build/$BUILDARCH/workdir
umount -lfd $RBOSLOCATION/build/$BUILDARCH/phase_2

#Compare the /tmp/INSTALLS.txt file from previous builds, to the current one. If the current one has missing lines, (meaning that a package should not be installed) then reset phase 2.
INSTALLREMOVECOUNT="$(diff -uN $RBOSLOCATION/build/$BUILDARCH/phase_2/tmp/INSTALLS.txt.bak $ThIsScriPtSFolDerLoCaTion/../rebeccablacklinux_files/tmp/INSTALLS.txt | grep ^- | grep -v "\---" | wc -l)"
if [[ $INSTALLREMOVECOUNT -gt 0 || ! -f $RBOSLOCATION/DontRestartPhase2$BUILDARCH ]]
then
#Delete the phase 2 folder contents
rm -rf $RBOSLOCATION/build/$BUILDARCH/phase_2/*
touch $RBOSLOCATION/DontRestartPhase2$BUILDARCH
fi

#create the union of phases 1 and 2 at the workdir
mount -t aufs -o dirs=$RBOSLOCATION/build/$BUILDARCH/phase_2:$RBOSLOCATION/build/$BUILDARCH/phase_1 none $RBOSLOCATION/build/$BUILDARCH/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $RBOSLOCATION/build/$BUILDARCH/workdir/dev/
mount --rbind /proc $RBOSLOCATION/build/$BUILDARCH/workdir/proc/
mount --rbind /sys $RBOSLOCATION/build/$BUILDARCH/workdir/sys/


#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
linux32 chroot $RBOSLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase2.sh
else
chroot $RBOSLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase2.sh
fi


#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/dev

#unmount the debs data
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build/$BUILDARCH/workdir

