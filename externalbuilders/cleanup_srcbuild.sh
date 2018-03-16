#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016, 2017, 2018 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

HASOVERLAYFS=$(grep -c overlay$ /proc/filesystems)
if [[ $HASOVERLAYFS == 0 ]]
then
  HASOVERLAYFSMODULE=$(modprobe -n overlay; echo $?)
  if [[ $HASOVERLAYFSMODULE == 0 ]]
  then
    HASOVERLAYFS=1
  fi
fi

HOMELOCATION=~
unset HOME

if [[ -z "$BUILDARCH" || -z "$BUILDLOCATION" || $UID != 0 ]]
then
  echo "BUILDARCH variable not set, or BUILDLOCATION not set, or not run as root. This external build script should be called by the main build script."
  exit
fi

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
mount --make-rprivate /

#Use phase_1 as the system to cleanup srcbuild
if [[ $HASOVERLAYFS == 0 ]]
then
  #bind mount phase1 to the workdir. 
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/usr/bin/Compile/*
  #copy the files to where they belong
  rsync "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/* -CKr "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/ 
else
  #Union mount importdata and phase1
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/unionwork
  mount -t overlay overlay -o lowerdir="$BUILDLOCATION"/build/"$BUILDARCH"/importdata,upperdir="$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME,workdir="$BUILDLOCATION"/build/"$BUILDARCH"/unionwork "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
fi

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev
mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc
mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys

#Bind mount shared directories
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/buildlogs
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/buildlogs


#Call compile_all to cleanup srcbuild########################################
TARGETBITSIZE=$(chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/getconf LONG_BIT)
if [[ $TARGETBITSIZE == 32 ]]
then
  linux32 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/compile_all clean
elif [[ $TARGETBITSIZE == 64 ]]
then
  linux64 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/compile_all clean
else
  echo "chroot execution failed. Please ensure your processor can handle the "$BUILDARCH" architecture, or that the target system isn't corrupt."
fi
