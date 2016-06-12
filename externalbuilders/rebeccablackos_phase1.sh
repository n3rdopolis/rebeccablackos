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
echo "PHASE 1"
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


#copy in the files needed
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
rsync "$SCRIPTFOLDERPATH"/../rebeccablackos_files/* -Cr "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/
rsync "$SCRIPTFOLDERPATH"/../* -Cr "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource

#Support importing the control file to use fixed revisions of the source code
rm "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt
rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/buildcore_revisions.txt
rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/buildcore_revisions.txt
rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/tmp/buildcore_revisions.txt
if [ -s "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt ]
then
  cp "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt
  rm "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt
  touch "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt
fi

#delete old logs
rm -r "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/usr/share/logs/*

#copy the dselect data saved in phase 2 into phase 1
cp "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLSSTATUS.txt "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/INSTALLSSTATUS.txt

#make the imported files executable 
chmod 0755 -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
chown  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
chgrp  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/


if [[ $HASOVERLAYFS == 0 ]]
then
  #bind mount phase1 to the workdir. 
  NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1 "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
  OLDPWD=$PWD
  cd "$BUILDLOCATION"/build/"$BUILDARCH"/importdata
  RESULT=$?
    if [[ $RESULT == 0 ]]
    then
      find | grep -v ^./etc | while read FILE 
      do
	rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/"$FILE" &> /dev/null
      done
    fi
  cd $OLDPWD
  NAMESPACE_ENTER rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/usr/bin/Compile/*
  #copy the files to where they belong
  NAMESPACE_ENTER rsync "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/* -Cr "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/ 
else
  #Union mount importdata and phase1
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/unionwork
  NAMESPACE_ENTER mount -t overlay overlay -o lowerdir="$BUILDLOCATION"/build/"$BUILDARCH"/importdata,upperdir="$BUILDLOCATION"/build/"$BUILDARCH"/phase_1,workdir="$BUILDLOCATION"/build/"$BUILDARCH"/unionwork "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
fi

#mounting critical fses on chrooted fs with bind 
NAMESPACE_ENTER mount --rbind /dev "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev
NAMESPACE_ENTER mount --rbind /proc "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc
NAMESPACE_ENTER mount --rbind /sys "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys
NAMESPACE_ENTER mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm
NAMESPACE_ENTER mount --bind /run/shm "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm

#Mount in the folder with previously built debs
NAMESPACE_ENTER mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput
NAMESPACE_ENTER mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives



#Configure the Live system########################################
TARGETBITSIZE=$(NAMESPACE_ENTER chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /usr/bin/getconf LONG_BIT)
if [[ $TARGETBITSIZE == 32 ]]
then
  NAMESPACE_ENTER linux32 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase1.sh
elif [[ $TARGETBITSIZE == 64 ]]
then
  NAMESPACE_ENTER linux64 chroot "$BUILDLOCATION"/build/"$BUILDARCH"/workdir /tmp/configure_phase1.sh
else
  echo "chroot execution failed. Please ensure your processor can handle the "$BUILDARCH" architecture, or that the target system isn't corrupt."
fi

#Kill the namespace's PID 1
kill -9 $ROOTPID