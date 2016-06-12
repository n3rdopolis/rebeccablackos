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

#Create the PID and Mount namespaces, pid 1 to sleep forever
unshare -f --pid --mount --mount-proc sleep infinity &
UNSHAREPID=$!

#Get the PID of the unshared process, which is pid 1 for the namespace, wait at the very most 1 minute for the process to start, 120 attempts with half 1 second intervals.
#Abort if not started in 1 minute
for (( element = 0 ; element < 120 ; element++ ))
do
  echo $element
  ROOTPID=$(pgrep -P $UNSHAREPID)
  if [[ ! -z $ROOTPID ]]
  then
    break
  fi
  sleep .5
done
if [[ ! -z $ROOTPID ]]
then
  echo "The main namespace process failed to start, in 1 minute. This should not take that long"
  exit
fi

#Log the PID of the sleep command, so that it can be cleaned up if the script crashes
echo $ROOTPID > "$BUILDLOCATION"/build/"$BUILDARCH"/pidlist

#Define the command for entering the namespace now that $ROOTPID is defined
function NAMESPACE_ENTER {
  nsenter --mount --target $ROOTPID --pid --target $ROOTPID "$@"
}

#delete old logs
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/usr/share/logs/*

#copy the installs data copied in phase 1 into phase 2 
cp "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/INSTALLS.txt "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt 


#bind mount phase2 at the workdir
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2 "$BUILDLOCATION"/build/"$BUILDARCH"/workdir

#mounting critical fses on chrooted fs with bind 
NAMESPACE_ENTER mount --rbind /dev "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev
NAMESPACE_ENTER mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc
NAMESPACE_ENTER mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys
NAMESPACE_ENTER mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm
NAMESPACE_ENTER mount --bind /run/shm "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm

#Mount in the folder with previously built debs
NAMESPACE_ENTER mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives

#Bring in needed files.
NAMESPACE_ENTER rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/lib/apt/lists/*
NAMESPACE_ENTER cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/*     "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/tmp
NAMESPACE_ENTER cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/etc/apt/sources.list "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/etc/apt/sources.list 
NAMESPACE_ENTER cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/*.bin "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt
NAMESPACE_ENTER cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/lib/apt/lists "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/lib/apt

#Configure the Live system########################################
TARGETBITSIZE=$(NAMESPACE_ENTER chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/getconf LONG_BIT)
if [[ $TARGETBITSIZE == 32 ]]
then
  NAMESPACE_ENTER linux32 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase2.sh
elif [[ $TARGETBITSIZE == 64 ]]
then
  NAMESPACE_ENTER linux64 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase2.sh
else
  echo "chroot execution failed. Please ensure your processor can handle the "$BUILDARCH" architecture, or that the target system isn't corrupt."
fi

#Kill the namespace's PID 1
kill -9 $ROOTPID