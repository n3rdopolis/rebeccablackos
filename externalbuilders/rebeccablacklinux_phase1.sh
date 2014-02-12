#! /bin/bash
#    Copyright (c) 2012, 2013, 2014 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
mkdir -p $BUILDLOCATION/build/$BUILDARCH
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_1
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_3
mkdir -p $BUILDLOCATION/build/$BUILDARCH/srcbuild
mkdir -p $BUILDLOCATION/build/$BUILDARCH/buildoutput
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir
mkdir -p $BUILDLOCATION/build/$BUILDARCH/archives

#unmount the chrooted procfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/dev

#unmount the external archive folder
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/var/cache/apt/archives

#unmount the source download folder
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild

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
rm -r $BUILDLOCATION/build/$BUILDARCH/phase_1/usr/share/logs/*

#copy the dselect data saved in phase 2 into phase 1
cp $BUILDLOCATION/build/$BUILDARCH/phase_2/tmp/INSTALLSSTATUS.txt $BUILDLOCATION/build/$BUILDARCH/phase_1/tmp/INSTALLSSTATUS.txt

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
mount --bind $BUILDLOCATION/build/$BUILDARCH/srcbuild $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild
mount --bind $BUILDLOCATION/build/$BUILDARCH/buildoutput $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --bind $BUILDLOCATION/build/$BUILDARCH/archives $BUILDLOCATION/build/$BUILDARCH/workdir/var/cache/apt/archives


#bring these files into phase_1 with aufs
cp -a $BUILDLOCATION/build/$BUILDARCH/importdata/tmp/*     $BUILDLOCATION/build/$BUILDARCH/workdir/tmp
cp -a $BUILDLOCATION/build/$BUILDARCH/importdata/etc/apt/sources.list $BUILDLOCATION/build/$BUILDARCH/workdir/etc/apt/sources.list 


#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
  linux32 chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
else
  chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
fi

#unmount the external archive folder
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/var/cache/apt/archives

#unmount the chrooted procfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/sys

#unmount the debs data
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#unmount the source download folder
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild

#unmount the FS at the workdir
umount -lfd $BUILDLOCATION/build/$BUILDARCH/workdir
