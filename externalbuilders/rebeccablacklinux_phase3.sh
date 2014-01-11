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
echo "PHASE 3"  
SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

HOMELOCATION=~
BUILDLOCATION=~/RBOS_Build_Files
unset HOME

if [[ -z $BUILDARCH ]]
then
  echo "BUILDARCH variable not set"
  exit
fi

#If the lockfile for the build output does not exist, delete it so all debs get deleted, and the build restarts from scratch.
if [[  ! -f $BUILDLOCATION/DontRestartBuildoutput$BUILDARCH ]]
then
  rm -rf $BUILDLOCATION/build/$BUILDARCH/buildoutput
  touch $BUILDLOCATION/DontRestartBuildoutput$BUILDARCH 
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

#Clean up Phase 3 data.
rm -rf $BUILDLOCATION/build/$BUILDARCH/phase_3/*

#create the union of phases 1, 2, and 3 at workdir
mount -t aufs -o dirs=$BUILDLOCATION/build/$BUILDARCH/phase_3:$BUILDLOCATION/build/$BUILDARCH/phase_2:$BUILDLOCATION/build/$BUILDARCH/phase_1 none $BUILDLOCATION/build/$BUILDARCH/workdir


#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $BUILDLOCATION/build/$BUILDARCH/workdir/dev/
mount --rbind /proc $BUILDLOCATION/build/$BUILDARCH/workdir/proc/
mount --rbind /sys $BUILDLOCATION/build/$BUILDARCH/workdir/sys/

#Mount in the folder with previously built debs
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --rbind $BUILDLOCATION/build/$BUILDARCH/buildoutput $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#copy the files to where they belong
rsync $BUILDLOCATION/build/$BUILDARCH/importdata/* -Cr $BUILDLOCATION/build/$BUILDARCH/workdir/

#Handle /usr/import for the creation of the deb file that contains this systems files
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir/usr/import
rsync $BUILDLOCATION/build/$BUILDARCH/importdata/* -Cr $BUILDLOCATION/build/$BUILDARCH/workdir/usr/import
rm -rf $BUILDLOCATION/build/$BUILDARCH/workdir/usr/import/usr/import

#delete the temp folder
rm -rf $BUILDLOCATION/build/$BUILDARCH/workdir/temp/


#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
  linux32 chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase3.sh
else
  chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase3.sh
fi


#Create a date string for unique log folder names
ENDDATE=$(date +"%Y-%m-%d %H-%M-%S")

#Create a folder for the log files with the date string
mkdir -p "$BUILDLOCATION/logs/$ENDDATE $BUILDARCH"

#Export the log files to the location
cp -a "$BUILDLOCATION/build/$BUILDARCH/workdir/usr/share/logs/"* "$BUILDLOCATION/logs/$ENDDATE $BUILDARCH"

#If the live cd did not build then tell user  
if [ ! -f $BUILDLOCATION/build/$BUILDARCH/workdir/home/remastersys/remastersys/custom.iso ];
then  
  echo "The Live CD did not succesfuly build. The script could have been modified, or a network connection could have failed to one of the servers preventing the installation packages for Ubuntu, or Remstersys from installing. There could also be a problem with the selected architecture for the build, such as an incompatible kernel or CPU, or a misconfigured qemu-system bin_fmt"

fi 

#If the live cd did  build then tell user   
if [  -f $BUILDLOCATION/build/$BUILDARCH/workdir/home/remastersys/remastersys/custom.iso ];
then  
  #move the iso out of the chroot fs    
  mv $BUILDLOCATION/build/$BUILDARCH/phase_3/home/remastersys/remastersys/custom-full.iso $HOMELOCATION/RebeccaBlackLinux_$BUILDARCH.iso
  mv $BUILDLOCATION/build/$BUILDARCH/phase_3/home/remastersys/remastersys/custom.iso $HOMELOCATION/RebeccaBlackLinux_Reduced_$BUILDARCH.iso

  echo "Live CD image build was successful."

  #allow the user to actually read the iso   
  chown $SUDO_USER $HOMELOCATION/RebeccaBlackLinux*.iso
  chgrp $SUDO_USER $HOMELOCATION/RebeccaBlackLinux*.iso
  chmod 777 $HOMELOCATION/RebeccaBlackLinux*.iso
fi


#unmount the chrooted procfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/dev

#unmount the debs data
umount -lf $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput

#unmount the FS at the workdir
umount -lfd $BUILDLOCATION/build/$BUILDARCH/workdir

#Clean up Phase 3 data.
rm -rf $BUILDLOCATION/build/$BUILDARCH/phase_3/*