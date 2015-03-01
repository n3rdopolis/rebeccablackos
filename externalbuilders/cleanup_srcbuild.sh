#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

HOMELOCATION=~
unset HOME

if [[ -z "$BUILDARCH" || -z "$BUILDLOCATION" || $UID != 0 ]]
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
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp

#Use phase_1 as the system to cleanup srcbuild
mount --rbind "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1 "$BUILDLOCATION"/build/"$BUILDARCH"/workdir


#mounting critical fses on chrooted fs with bind 
mount --rbind /dev "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev/
mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc/
mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys/

#Mount in the folder with previously built debs
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput
mount --rbind "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild



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
