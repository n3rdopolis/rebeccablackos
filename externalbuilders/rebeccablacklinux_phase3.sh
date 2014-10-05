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
unset HOME

if [[ -z $BUILDARCH || -z $BUILDLOCATION || $UID != 0 ]]
then
  echo "BUILDARCH variable not set, or BUILDLOCATION not set, or not run as root. This external build script should be called by the main build script."
  exit
fi

#create a folder for the media mountpoints in the media folder
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/phase_1
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/phase_2
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/phase_3
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/buildoutput
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/archives
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/remastersys
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/vartmp

#Clean up Phase 3 data.
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_3/*

#Copy phase3 from phase2, and bind mount phase3 at the workdir
echo "Duplicating Phase 2 for usage in Phase 3. This may take some time..."
cp --reflink=auto -a "$BUILDLOCATION"/build/$BUILDARCH/phase_2/. "$BUILDLOCATION"/build/$BUILDARCH/phase_3
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/phase_3 "$BUILDLOCATION"/build/$BUILDARCH/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev "$BUILDLOCATION"/build/$BUILDARCH/workdir/dev/
mount --rbind /proc "$BUILDLOCATION"/build/$BUILDARCH/workdir/proc/
mount --rbind /sys "$BUILDLOCATION"/build/$BUILDARCH/workdir/sys/

#Mount in the folder with previously built debs
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir/home/remastersys
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir/var/tmp
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/srcbuild "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/buildoutput "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --rbind  "$BUILDLOCATION"/build/$BUILDARCH/remastersys "$BUILDLOCATION"/build/$BUILDARCH/workdir/home/remastersys
mount --rbind  "$BUILDLOCATION"/build/$BUILDARCH/vartmp "$BUILDLOCATION"/build/$BUILDARCH/workdir/var/tmp

#copy the files to where they belong
rsync "$BUILDLOCATION"/build/$BUILDARCH/importdata/* -Cr "$BUILDLOCATION"/build/$BUILDARCH/workdir/

#Handle /usr/import for the creation of the deb file that contains this systems files
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir/usr/import
rsync "$BUILDLOCATION"/build/$BUILDARCH/importdata/* -Cr "$BUILDLOCATION"/build/$BUILDARCH/workdir/usr/import
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/workdir/usr/import/usr/import

#delete the temp folder
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/workdir/temp/


#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
  linux32 chroot "$BUILDLOCATION"/build/$BUILDARCH/workdir /tmp/configure_phase3.sh
else
  chroot "$BUILDLOCATION"/build/$BUILDARCH/workdir /tmp/configure_phase3.sh
fi


#Create a date string for unique log folder names
ENDDATE=$(date +"%Y-%m-%d %H-%M-%S")

#Create a folder for the log files with the date string
mkdir -p ""$BUILDLOCATION"/logs/$ENDDATE $BUILDARCH"

#Export the log files to the location
cp -a ""$BUILDLOCATION"/build/$BUILDARCH/phase_1/usr/share/logs/"* ""$BUILDLOCATION"/logs/$ENDDATE $BUILDARCH"
cp -a ""$BUILDLOCATION"/build/$BUILDARCH/workdir/usr/share/logs/"* ""$BUILDLOCATION"/logs/$ENDDATE $BUILDARCH"
rm ""$BUILDLOCATION"/logs/latest"
ln -s ""$BUILDLOCATION"/logs/$ENDDATE $BUILDARCH" ""$BUILDLOCATION"/logs/latest"
cp -a ""$BUILDLOCATION"/build/$BUILDARCH/workdir/usr/share/build_core_revisions.txt" ""$BUILDLOCATION"/logs/$ENDDATE $BUILDARCH" 
cp -a ""$BUILDLOCATION"/build/$BUILDARCH/workdir/usr/share/build_core_revisions.txt" ""$HOMELOCATION"/RebeccaBlackLinux_Revisions_$BUILDARCH.txt"
#If the live cd did not build then tell user  
if [[ ! -f "$BUILDLOCATION"/build/$BUILDARCH/workdir/home/remastersys/remastersys/custom-full.iso ]]
then  
  ISOFAILED=1
else
    mv "$BUILDLOCATION"/build/$BUILDARCH/remastersys/remastersys/custom-full.iso "$HOMELOCATION"/RebeccaBlackLinux_DevDbg_$BUILDARCH.iso
fi 
if [[ ! -f "$BUILDLOCATION"/build/$BUILDARCH/workdir/home/remastersys/remastersys/custom.iso ]]
then  
  ISOFAILED=1
else
    mv "$BUILDLOCATION"/build/$BUILDARCH/remastersys/remastersys/custom.iso "$HOMELOCATION"/RebeccaBlackLinux_$BUILDARCH.iso
fi 


#allow the user to actually read the iso   
chown $SUDO_USER "$HOMELOCATION"/RebeccaBlackLinux*.iso RebeccaBlackLinux_*.txt
chgrp $SUDO_USER "$HOMELOCATION"/RebeccaBlackLinux*.iso RebeccaBlackLinux_*.txt
chmod 777 "$HOMELOCATION"/RebeccaBlackLinux*.iso RebeccaBlackLinux_*.txt

#If the live cd did  build then tell user   
if [[ $ISOFAILED != 1  ]];
then  
  echo "Live CD image build was successful."
else
  echo "The Live CD did not succesfuly build. The script could have been modified, or a network connection could have failed to one of the servers preventing the installation packages for Ubuntu, or Remstersys from installing. There could also be a problem with the selected architecture for the build, such as an incompatible kernel or CPU, or a misconfigured qemu-system bin_fmt"
fi

