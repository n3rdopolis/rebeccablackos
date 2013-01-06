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

RBOSLOCATION=~/RBOS_Build_Files
unset HOME

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the FS at the workdir and phase 2
umount -lfd $RBOSLOCATION/build_mountpoints/workdir
umount -lfd $RBOSLOCATION/build_mountpoints/phase_2


#END PAST RUN CLEANUP##################


#bind mount the FS to the workdir if there is no phase 2. If there is a phase 2, create a union of the phases.
INSTALLREMOVECOUNT="$(diff -uN $RBOSLOCATION/build_mountpoints/phase_2/tmp/INSTALLS.txt.bak $ThIsScriPtSFolDerLoCaTion/../rebeccablacklinux_files/tmp/INSTALLS.txt | grep ^- | grep -v "\---" | wc -l)"
if [[ $INSTALLREMOVECOUNT -gt 0 || ! -f $RBOSLOCATION/DontRestartPhase2 ]]
then
mount --bind $RBOSLOCATION/build_mountpoints/phase_1 $RBOSLOCATION/build_mountpoints/workdir
else 
mount -t overlayfs -o lowerdir=$RBOSLOCATION/build_mountpoints/phase_1,upperdir=$RBOSLOCATION/build_mountpoints/phase_2 overlayfs $RBOSLOCATION/build_mountpoints/workdir
fi

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $RBOSLOCATION/build_mountpoints/workdir/dev/
mount --rbind /proc $RBOSLOCATION/build_mountpoints/workdir/proc/
mount --rbind /sys $RBOSLOCATION/build_mountpoints/workdir/sys/

#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr $RBOSLOCATION/build_mountpoints/workdir/temp/


#make the imported files executable 
chmod +x -R $RBOSLOCATION/build_mountpoints/workdir/temp/
chown  root  -R $RBOSLOCATION/build_mountpoints/workdir/temp/
chgrp  root  -R $RBOSLOCATION/build_mountpoints/workdir/temp/

#copy the ONLY minimal build files in, not any data files like wallpapers.
mkdir -p $RBOSLOCATION/build_mountpoints/workdir/usr/bin/Compile/
cp -a $RBOSLOCATION/build_mountpoints/workdir/temp/tmp/* $RBOSLOCATION/build_mountpoints/workdir/tmp
cp -a $RBOSLOCATION/build_mountpoints/workdir/temp/usr/bin/Compile/* $RBOSLOCATION/build_mountpoints/workdir/usr/bin/Compile/
cp $RBOSLOCATION/build_mountpoints/workdir/temp/usr/bin/compile_all $RBOSLOCATION/build_mountpoints/workdir/usr/bin/compile_all 
cp $RBOSLOCATION/build_mountpoints/workdir/temp/usr/bin/build_core $RBOSLOCATION/build_mountpoints/workdir/usr/bin/build_core
cp $RBOSLOCATION/build_mountpoints/workdir/temp/usr/bin/build_vars $RBOSLOCATION/build_mountpoints/workdir/usr/bin/build_vars
cp $RBOSLOCATION/build_mountpoints/workdir/temp/usr/bin/weston_vars $RBOSLOCATION/build_mountpoints/workdir/usr/bin/weston_vars
cp $RBOSLOCATION/build_mountpoints/workdir/temp/etc/apt/sources.list $RBOSLOCATION/build_mountpoints/workdir/etc/apt/sources.list 

#delete the temp folder
rm -rf $RBOSLOCATION/build_mountpoints/workdir/temp/



#Configure the Live system########################################
chroot $RBOSLOCATION/build_mountpoints/workdir /tmp/configure_phase1.sh


#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build_mountpoints/workdir
