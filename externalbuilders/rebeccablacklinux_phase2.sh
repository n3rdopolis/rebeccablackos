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
echo "PHASE 2"  
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

#create a folder for the media mountpoints in the media folder
mkdir -p $BUILDLOCATION/build/$BUILDARCH
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_1
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2
mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_3
mkdir -p $BUILDLOCATION/build/$BUILDARCH/srcbuild
mkdir -p $BUILDLOCATION/build/$BUILDARCH/buildoutput
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir
mkdir -p $BUILDLOCATION/build/$BUILDARCH/archives

#Reset phase 2 if DontRestartPhase2 file is missing.
if [[ ! -f $BUILDLOCATION/DontRestartPhase2$BUILDARCH ]]
then
  #Delete the phase 2 folder contents
  rm -rf $BUILDLOCATION/build/$BUILDARCH/phase_2/*
  touch $BUILDLOCATION/DontRestartPhase2$BUILDARCH
  mkdir -p $BUILDLOCATION/build/$BUILDARCH/phase_2/tmp
  touch $BUILDLOCATION/build/$BUILDARCH/phase_2/tmp/INSTALLS.txt.bak
fi

#delete old logs
rm -r $BUILDLOCATION/build/$BUILDARCH/phase_2/usr/share/logs/*

#copy the installs data copied in phase 1 into phase 2 
cp $BUILDLOCATION/build/$BUILDARCH/importdata/tmp/INSTALLS.txt $BUILDLOCATION/build/$BUILDARCH/phase_2/tmp/INSTALLS.txt 


#create the union of phases 1 and 2 at the workdir
mount -t aufs -o dirs=$BUILDLOCATION/build/$BUILDARCH/phase_2:$BUILDLOCATION/build/$BUILDARCH/phase_1 none $BUILDLOCATION/build/$BUILDARCH/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $BUILDLOCATION/build/$BUILDARCH/workdir/dev/
mount --rbind /proc $BUILDLOCATION/build/$BUILDARCH/workdir/proc/
mount --rbind /sys $BUILDLOCATION/build/$BUILDARCH/workdir/sys/

#Mount in the folder with previously built debs
mkdir -p $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --bind $BUILDLOCATION/build/$BUILDARCH/srcbuild $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild
mount --bind $BUILDLOCATION/build/$BUILDARCH/buildoutput $BUILDLOCATION/build/$BUILDARCH/workdir/srcbuild/buildoutput
mount --bind $BUILDLOCATION/build/$BUILDARCH/archives $BUILDLOCATION/build/$BUILDARCH/workdir/var/cache/apt/archives



#Configure the Live system########################################
if [[ $BUILDARCH == i386 ]]
then
  linux32 chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase2.sh
else
  chroot $BUILDLOCATION/build/$BUILDARCH/workdir /tmp/configure_phase2.sh
fi