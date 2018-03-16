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
echo "PHASE 3"  
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

unset HOME

if [[ -z "$BUILDARCH" || -z $BUILDLOCATION || $UID != 0 ]]
then
  echo "BUILDARCH variable not set, or BUILDLOCATION not set, or not run as root. This external build script should be called by the main build script."
  exit
fi

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
mount --make-rprivate /

if [[ $HASOVERLAYFS == 0 ]]
then
  #Copy phase3 from phase2, and bind mount phase3 at the workdir
  echo "Duplicating Phase 2 for usage in Phase 3. This may take some time..."
  cp --reflink=auto -a "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/. "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3 "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
else
  #Union mount phase2 and phase3
  if [[ -d "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/phase_3 ]]
  then
    mount -t overlay overlay -o lowerdir="$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME,upperdir="$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/phase_3,workdir="$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
  else
    mount -t overlay overlay -o lowerdir="$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME,upperdir="$BUILDLOCATION"/build/"$BUILDARCH"/phase_3,workdir="$BUILDLOCATION"/build/"$BUILDARCH"/unionwork "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
  fi
fi

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev
mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc
mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm
mount --bind /run/shm "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm

#Bind mount shared directories
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/home/remastersys
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/tmp
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/buildlogs
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/tmp/srcbuild_overlay

#If no overlayfs is supported, set up srcbuild as a normal bind mount into the system, if overlayfs is supported, and there is enough ram, use the ramdisk as the upperdir, if not, use a path on the same filesystem as the upperdir
if [[ $HASOVERLAYFS == 0 ]]
then
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild
else
  if [[ -d "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/srcbuild_overlay ]]
  then
    mount -t overlay overlay -o  lowerdir="$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild,upperdir="$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/srcbuild_overlay,workdir="$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork_srcbuild "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/
    mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/srcbuild_overlay "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/tmp/srcbuild_overlay
  else
    mount -t overlay overlay -o  lowerdir="$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild,upperdir="$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay,workdir="$BUILDLOCATION"/build/"$BUILDARCH"/unionwork_srcbuild "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/
    mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/tmp/srcbuild_overlay
  fi
fi

mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput
mount --bind  "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/home/remastersys
mount --bind  "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/tmp
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/buildlogs

#copy the files to where they belong
rsync "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/* -CKr "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/

#Handle /usr/import for the creation of the deb file that contains this systems files
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/usr/import
rsync "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/* -CKr "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/usr/import
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/usr/import/usr/import

#delete the temp folder
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/temp/


#Configure the Live system########################################
TARGETBITSIZE=$(chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/getconf LONG_BIT)
if [[ $TARGETBITSIZE == 32 ]]
then
  linux32 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase3.sh
elif [[ $TARGETBITSIZE == 64 ]]
then
  linux64 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase3.sh
else
  echo "chroot execution failed. Please ensure your processor can handle the "$BUILDARCH" architecture, or that the target system isn't corrupt."
fi

