#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
echo "PHASE 2"  
SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

unset HOME

if [[ -z "$BUILDARCH" || -z $BUILDLOCATION || $UID != 0 ]]
then
  echo "BUILDARCH variable not set, or BUILDLOCATION not set, or not run as root. This external build script should be called by the main build script."
  exit
fi

#create a folder for the media mountpoints in the media folder
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/archives
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
mount --make-rprivate /

#copy the installs data copied in phase 1 into phase 2 
cp "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/INSTALLS.txt "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt 


#bind mount phase2 at the workdir
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2 "$BUILDLOCATION"/build/"$BUILDARCH"/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev
mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc
mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm
mount --bind /run/shm "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm

#Mount in the folder with previously built debs
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/logs/buildlogs
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/logs/buildlogs

#Bring in needed files.
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/lib/apt/lists/*
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/*     "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/tmp
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/etc/apt/sources.list "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/etc/apt/sources.list 
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/*.bin "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/lib/apt/lists "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/lib/apt

#Configure the Live system########################################
TARGETBITSIZE=$(chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/getconf LONG_BIT)
if [[ $TARGETBITSIZE == 32 ]]
then
  linux32 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase2.sh
elif [[ $TARGETBITSIZE == 64 ]]
then
  linux64 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase2.sh
else
  echo "chroot execution failed. Please ensure your processor can handle the "$BUILDARCH" architecture, or that the target system isn't corrupt."
fi
