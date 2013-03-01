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
echo "PHASE 0"
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

RBOSLOCATION=~/RBOS_Build_Files
unset HOME

if [[ -z $BUILDARCH ]]
then
echo "BUILDARCH variable not set"
exit
fi

####CLEAN UP OLD SCRIPT FILES

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/dev

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build/$BUILDARCH/workdir

#unmount phase 2
umount -lf $RBOSLOCATION/build/$BUILDARCH/phase_2

#END PAST RUN CLEANUP##################


#make a folder containing the live cd tools in the users local folder
mkdir $RBOSLOCATION

#switch to that folder
cd $RBOSLOCATION

#clean up old files
rm -rf $RBOSLOCATION/build/$BUILDARCH/

#create a folder for the media mountpoints in the media folder
mkdir $RBOSLOCATION/build/$BUILDARCH
mkdir $RBOSLOCATION/build/$BUILDARCH/phase_1
mkdir $RBOSLOCATION/build/$BUILDARCH/phase_2
mkdir $RBOSLOCATION/build/$BUILDARCH/phase_3
mkdir $RBOSLOCATION/build/$BUILDARCH/buildoutput
mkdir $RBOSLOCATION/build/$BUILDARCH/workdir

#bind mount the FS to the workdir
mount --bind $RBOSLOCATION/build/$BUILDARCH/phase_1 $RBOSLOCATION/build/$BUILDARCH/workdir

#install a really basic Ubuntu installation in the new fs  
debootstrap --arch $BUILDARCH raring $RBOSLOCATION/build/$BUILDARCH/workdir http://ubuntu.osuosl.org/ubuntu/

#tell future calls of the first builder script that phase 1 is done
touch $RBOSLOCATION/DontStartFromScratch$BUILDARCH

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build/$BUILDARCH/workdir/dev

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build/$BUILDARCH/workdir
