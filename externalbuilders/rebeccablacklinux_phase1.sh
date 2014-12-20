#! /bin/bash
#    Copyright (c) 2012, 2013, 2014 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
#
#    This file is part of RebeccaBlackOS.
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


#copy in the files needed
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/importdata/
rsync "$SCRIPTFOLDERPATH"/../rebeccablacklinux_files/* -Cr "$BUILDLOCATION"/build/$BUILDARCH/importdata/
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/exportsource/
rsync "$SCRIPTFOLDERPATH"/../* -Cr "$BUILDLOCATION"/build/$BUILDARCH/exportsource

#Support importing the control file to use fixed revisions of the source code
rm "$BUILDLOCATION"/build/$BUILDARCH/importdata/tmp/buildcore_revisions.txt
rm "$BUILDLOCATION"/build/$BUILDARCH/phase_1/tmp/buildcore_revisions.txt
rm "$BUILDLOCATION"/build/$BUILDARCH/phase_2/tmp/buildcore_revisions.txt
rm "$BUILDLOCATION"/build/$BUILDARCH/phase_3/tmp/buildcore_revisions.txt
if [[ -e "$BUILDLOCATION"/RebeccaBlackLinux_Revisions_$BUILDARCH.txt ]]
then
  cp "$BUILDLOCATION"/RebeccaBlackLinux_Revisions_$BUILDARCH.txt "$BUILDLOCATION"/build/$BUILDARCH/importdata/tmp/buildcore_revisions.txt
  rm "$BUILDLOCATION"/RebeccaBlackLinux_Revisions_$BUILDARCH.txt
fi

#delete old logs
rm -r "$BUILDLOCATION"/build/$BUILDARCH/phase_1/usr/share/logs/*

#copy the dselect data saved in phase 2 into phase 1
cp "$BUILDLOCATION"/build/$BUILDARCH/phase_2/tmp/INSTALLSSTATUS.txt "$BUILDLOCATION"/build/$BUILDARCH/phase_1/tmp/INSTALLSSTATUS.txt

#make the imported files executable 
chmod 0755 -R "$BUILDLOCATION"/build/$BUILDARCH/importdata/
chown  root  -R "$BUILDLOCATION"/build/$BUILDARCH/importdata/
chgrp  root  -R "$BUILDLOCATION"/build/$BUILDARCH/importdata/

#bind mount phase1 to the workdir. 
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/phase_1 "$BUILDLOCATION"/build/$BUILDARCH/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev "$BUILDLOCATION"/build/$BUILDARCH/workdir/dev/
mount --rbind /proc "$BUILDLOCATION"/build/$BUILDARCH/workdir/proc/
mount --rbind /sys "$BUILDLOCATION"/build/$BUILDARCH/workdir/sys/

#Mount in the folder with previously built debs
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/workdir/var/cache/apt/archives
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/srcbuild "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/buildoutput "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --rbind "$BUILDLOCATION"/build/$BUILDARCH/archives "$BUILDLOCATION"/build/$BUILDARCH/workdir/var/cache/apt/archives

#copy the files to where they belong
rsync "$BUILDLOCATION"/build/$BUILDARCH/importdata/* -Cr "$BUILDLOCATION"/build/$BUILDARCH/workdir/ 


#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
  linux32 chroot "$BUILDLOCATION"/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
else
  chroot "$BUILDLOCATION"/build/$BUILDARCH/workdir /tmp/configure_phase1.sh
fi