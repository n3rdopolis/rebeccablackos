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
SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

BUILDLOCATION=~/RBOS_Build_Files
unset HOME

if [[ -z $BUILDARCH ]]
then
echo "BUILDARCH variable not set"
exit
fi

#create a folder for the media mountpoints in the media folder
mkdir $BUILDLOCATION/build/$BUILDARCH
mkdir $BUILDLOCATION/build/$BUILDARCH/phase_1
mkdir $BUILDLOCATION/build/$BUILDARCH/phase_2
mkdir $BUILDLOCATION/build/$BUILDARCH/phase_3
mkdir $BUILDLOCATION/build/$BUILDARCH/buildoutput
mkdir $BUILDLOCATION/build/$BUILDARCH/workdir

#unmount the chrooted procfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/dev

#unmount the debs data
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#unmount the FS at the workdir and phase 2
umount -lfd $BUILDLOCATION/build/$BUILDARCH/workdir
umount -lfd $BUILDLOCATION/build/$BUILDARCH/phase_2



#END PAST RUN CLEANUP##################

#copy in the files needed
rm -rf $BUILDLOCATION/build/$BUILDARCH/importdata/
rsync "$SCRIPTFOLDERPATH"/../rebeccablacklinux_files/* -Cr $BUILDLOCATION/build/$BUILDARCH/importdata/

#delete old logs
rm $BUILDLOCATION/build/$BUILDARCH/phase_1/usr/share/logs/

#make the imported files executable 
chmod 0755 -R $BUILDLOCATION/build/$BUILDARCH/importdata/
chown  root  -R $BUILDLOCATION/build/$BUILDARCH/importdata/
chgrp  root  -R $BUILDLOCATION/build/$BUILDARCH/importdata/

#bind mount the FS to the workdir. 
mount -t aufs -o dirs=$BUILDLOCATION/build/$BUILDARCH/phase_1:$BUILDLOCATION/build/$BUILDARCH/importdata/ none $BUILDLOCATION/build/$BUILDARCH/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $BUILDLOCATION/build/$BUILDARCH/workdir/dev/
mount --rbind /proc $BUILDLOCATION/build/$BUILDARCH/workdir/proc/
mount --rbind /sys $BUILDLOCATION/build/$BUILDARCH/workdir/sys/

#Mount in the folder with previously built debs
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --rbind $BUILDLOCATION/build/$BUILDARCH/buildoutput $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#Import the old INSTALLS.txt file from the last build so it can be diffed
cp $BUILDLOCATION/build/$BUILDARCH/phase_2/tmp/INSTALLS.txt.bak $BUILDLOCATION/build/$BUILDARCH/workdir/tmp/

#bring these files into phase_1 with aufs
touch $BUILDLOCATION/build/$BUILDARCH/workdir/tmp/INSTALLS.txt
touch $BUILDLOCATION/build/$BUILDARCH/workdir/etc/apt/sources.list 


#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
linux32 chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
else
chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
fi

#unmount the chrooted procfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/sys

#unmount the debs data
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#unmount the FS at the workdir
umount -lfd $BUILDLOCATION/build/$BUILDARCH/workdir
