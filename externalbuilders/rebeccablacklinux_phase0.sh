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
echo "PHASE 0"
SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

unset HOME

if [[ -z $BUILDARCH || -z $BUILDLOCATION || $UID != 0 ]]
then
  echo "BUILDARCH variable not set, or BUILDLOCATION not set, or not run as root. This external build script should be called by the main build script."
  exit
fi

#make a folder containing the live cd tools in the users local folder
mkdir -p $BUILDLOCATION

#switch to that folder
cd $BUILDLOCATION

#create a folder for the media mountpoints in the media folder
mkdir -p $BUILDLOCATION/build/$BUILDARCH
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_1
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_3
mkdir -p $BUILDLOCATION/build/$BUILDARCH/srcbuild
mkdir -p $BUILDLOCATION/build/$BUILDARCH/buildoutput
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir
mkdir -p $BUILDLOCATION/build/$BUILDARCH/archives

#Initilize the two systems, Phase1 is the download system, for filling  $BUILDLOCATION/build/$BUILDARCH/archives and  $BUILDLOCATION/build/$BUILDARCH/srcbuild, and phase2 is the base of the installed system
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_1/var/cache/apt/archives
mount --bind $BUILDLOCATION/build/$BUILDARCH/archives $BUILDLOCATION/build/$BUILDARCH/phase_1/var/cache/apt/archives
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2/var/cache/apt/archives
mount --bind $BUILDLOCATION/build/$BUILDARCH/archives $BUILDLOCATION/build/$BUILDARCH/phase_2/var/cache/apt/archives

#Set the debootstrap dir
export DEBOOTSTRAP_DIR=$BUILDLOCATION/debootstrap

#setup a really basic Ubuntu installation for downloading 
#if set to rebuild phase 1
if [ ! -f $BUILDLOCATION/DontRestartPhase1$BUILDARCH ]
then
  echo "Setting up chroot for downloading archives and software..."
  $BUILDLOCATION/debootstrap/debootstrap --arch $BUILDARCH utopic $BUILDLOCATION/build/$BUILDARCH/phase_1 http://ubuntu.osuosl.org/ubuntu/
  touch $BUILDLOCATION/DontRestartPhase1$BUILDARCH
fi

#if set to rebuild phase 1
if [ ! -f $BUILDLOCATION/DontRestartPhase2$BUILDARCH ]
then
  #setup a really basic Ubuntu installation for the live cd
  echo "Setting up chroot for the Live CD..."
  $BUILDLOCATION/debootstrap/debootstrap --arch $BUILDARCH utopic $BUILDLOCATION/build/$BUILDARCH/phase_2 http://ubuntu.osuosl.org/ubuntu/
  touch $BUILDLOCATION/DontRestartPhase2$BUILDARCH
fi
