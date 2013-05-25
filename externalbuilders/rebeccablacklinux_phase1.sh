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
echo "PHASE 1"
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

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


#END PAST RUN CLEANUP##################


#bind mount the FS to the workdir. 
mount --bind $RBOSLOCATION/build/$BUILDARCH/phase_1 $RBOSLOCATION/build/$BUILDARCH/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $RBOSLOCATION/build/$BUILDARCH/workdir/dev/
mount --rbind /proc $RBOSLOCATION/build/$BUILDARCH/workdir/proc/
mount --rbind /sys $RBOSLOCATION/build/$BUILDARCH/workdir/sys/

#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr $RBOSLOCATION/build/$BUILDARCH/workdir/temp/


#make the imported files executable 
chmod 0744 -R $RBOSLOCATION/build/$BUILDARCH/workdir/temp/
chown  root  -R $RBOSLOCATION/build/$BUILDARCH/workdir/temp/
chgrp  root  -R $RBOSLOCATION/build/$BUILDARCH/workdir/temp/

#copy the ONLY minimal build files in, not any data files like wallpapers.
mkdir -p $RBOSLOCATION/build/$BUILDARCH/workdir/usr/bin/Compile/
cp -a $RBOSLOCATION/build/$BUILDARCH/workdir/temp/tmp/* $RBOSLOCATION/build/$BUILDARCH/workdir/tmp
cp -a $RBOSLOCATION/build/$BUILDARCH/workdir/temp/usr/bin/Compile/* $RBOSLOCATION/build/$BUILDARCH/workdir/usr/bin/Compile/
cp $RBOSLOCATION/build/$BUILDARCH/workdir/temp/usr/bin/compile_all $RBOSLOCATION/build/$BUILDARCH/workdir/usr/bin/compile_all 
cp $RBOSLOCATION/build/$BUILDARCH/workdir/temp/usr/bin/build_core $RBOSLOCATION/build/$BUILDARCH/workdir/usr/bin/build_core
cp $RBOSLOCATION/build/$BUILDARCH/workdir/temp/usr/bin/build_vars $RBOSLOCATION/build/$BUILDARCH/workdir/usr/bin/build_vars
cp $RBOSLOCATION/build/$BUILDARCH/workdir/temp/usr/bin/weston_vars $RBOSLOCATION/build/$BUILDARCH/workdir/usr/bin/weston_vars
cp $RBOSLOCATION/build/$BUILDARCH/workdir/temp/etc/apt/sources.list $RBOSLOCATION/build/$BUILDARCH/workdir/etc/apt/sources.list 

#delete the temp folder
rm -rf $RBOSLOCATION/build/$BUILDARCH/workdir/temp/



#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
linux32 chroot $RBOSLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
else
chroot $RBOSLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
fi

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/sys

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build/$BUILDARCH/workdir
