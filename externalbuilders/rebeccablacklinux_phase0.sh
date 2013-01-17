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
echo "PHASE 0"
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

RBOSLOCATION=~/RBOS_Build_Files
unset HOME

####CLEAN UP OLD SCRIPT FILES

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build_mountpoints/workdir

#unmount phase 2
umount -lf $RBOSLOCATION/build_mountpoints/phase_2

#END PAST RUN CLEANUP##################


#make a folder containing the live cd tools in the users local folder
mkdir $RBOSLOCATION

#switch to that folder
cd $RBOSLOCATION

#clean up old files
rm -rf $RBOSLOCATION/build_mountpoints/

#create a folder for the media mountpoints in the media folder
mkdir $RBOSLOCATION/build_mountpoints
mkdir $RBOSLOCATION/build_mountpoints/phase_1
mkdir $RBOSLOCATION/build_mountpoints/phase_2
mkdir $RBOSLOCATION/build_mountpoints/phase_3
mkdir $RBOSLOCATION/build_mountpoints/buildoutput
mkdir $RBOSLOCATION/build_mountpoints/workdir

#bind mount the FS to the workdir
mount --bind $RBOSLOCATION/build_mountpoints/phase_1 $RBOSLOCATION/build_mountpoints/workdir

#install a really basic Ubuntu installation in the new fs  
debootstrap raring $RBOSLOCATION/build_mountpoints/workdir http://ubuntu.osuosl.org/ubuntu/

#tell future calls of the first builder script that phase 1 is done
touch $RBOSLOCATION/DontStartFromScratch

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the FS at the workdir
umount -lfd $RBOSLOCATION/build_mountpoints/workdir
