#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
mount --make-rprivate /

#bind mount phase2 at the workdir
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME "$BUILDLOCATION"/build/"$BUILDARCH"/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/ "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev
mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc
mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/shm "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm

#Bind mount shared directories
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/buildlogs
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/buildlogs

#Bring in needed files.
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/*     "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/tmp
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/etc/apt/sources.list "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/etc/apt/sources.list 
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/etc/apt/preferences.d/
rm "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/etc/apt/preferences.d/*
cp "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/etc/apt/preferences.d/* "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/etc/apt/preferences.d/

if [[ -e "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/etc_apt_sources.list ]]
then
  cp "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/etc_apt_sources.list "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/etc/apt/sources.list
fi

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
