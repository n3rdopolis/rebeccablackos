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

BUILDLOCATION=~/RBOS_Build_Files
unset HOME

if [[ -z $BUILDARCH ]]
then
  echo "BUILDARCH variable not set"
  exit
fi

#make a folder containing the live cd tools in the users local folder
mkdir -p $BUILDLOCATION

#switch to that folder
cd $BUILDLOCATION

#clean up old files
rm -rf $BUILDLOCATION/build/$BUILDARCH/phase_1
rm -rf $BUILDLOCATION/build/$BUILDARCH/phase_2
rm -rf $BUILDLOCATION/build/$BUILDARCH/phase_3
rm -rf $BUILDLOCATION/build/$BUILDARCH/workdir
rm -rf $BUILDLOCATION/build/$BUILDARCH/importdata
rm -rf $BUILDLOCATION/build/$BUILDARCH/vartmp
rm -rf $BUILDLOCATION/build/$BUILDARCH/remastersys

#create a folder for the media mountpoints in the media folder
mkdir -p $BUILDLOCATION/build/$BUILDARCH
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_1
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_3
mkdir -p $BUILDLOCATION/build/$BUILDARCH/srcbuild
mkdir -p $BUILDLOCATION/build/$BUILDARCH/buildoutput
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir
mkdir -p $BUILDLOCATION/build/$BUILDARCH/archives

#bind mount the FS to the workdir, and bind mount the external archives folder
mount --bind $BUILDLOCATION/build/$BUILDARCH/phase_1 $BUILDLOCATION/build/$BUILDARCH/workdir
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir/var/cache/apt/archives
mount --bind $BUILDLOCATION/build/$BUILDARCH/archives $BUILDLOCATION/build/$BUILDARCH/workdir/var/cache/apt/archives
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2/var/cache/apt/archives
mount --bind $BUILDLOCATION/build/$BUILDARCH/archives $BUILDLOCATION/build/$BUILDARCH/phase_2/var/cache/apt/archives



#install a really basic Ubuntu installation for usage. 
echo "Setting up chroot for downloading archives and software..."
debootstrap --arch $BUILDARCH saucy $BUILDLOCATION/build/$BUILDARCH/workdir http://ubuntu.osuosl.org/ubuntu/
echo "Setting up chroot for the Live CD..."
debootstrap --arch $BUILDARCH saucy $BUILDLOCATION/build/$BUILDARCH/phase_2 http://ubuntu.osuosl.org/ubuntu/

#tell future calls of the first builder script that phase 1 is done
touch $BUILDLOCATION/DontStartFromScratch$BUILDARCH
touch $BUILDLOCATION/DontDebootstrap$BUILDARCH