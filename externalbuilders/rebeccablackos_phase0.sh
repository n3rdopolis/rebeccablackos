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
echo "PHASE 0"
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
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild
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


#Initilize the two systems, Phase1 is the download system, for filling  "$BUILDLOCATION"/build/"$BUILDARCH"/archives and  "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild, and phase2 is the base of the installed system
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/archives
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/archives
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt/archives
NAMESPACE_ENTER mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt/archives

#Set the debootstrap dir
export DEBOOTSTRAP_DIR="$BUILDLOCATION"/debootstrap

#setup a really basic Ubuntu installation for downloading 
#if set to rebuild phase 1
if [ ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" ]
then
  echo "Setting up chroot for downloading archives and software..."
  #NAMESPACE_ENTER "$BUILDLOCATION"/debootstrap/debootstrap --arch "$BUILDARCH" vivid "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1 http://archive.ubuntu.com/ubuntu
  NAMESPACE_ENTER "$BUILDLOCATION"/debootstrap/debootstrap --arch "$BUILDARCH" stretch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1 http://httpredir.debian.org/debian
  debootstrapresult=$?
  if [[ $debootstrapresult == 0 ]]
  then
    touch "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
  fi
fi

#if set to rebuild phase 1
if [ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]
then
  #setup a really basic Ubuntu installation for the live cd
  echo "Setting up chroot for the Live CD..."
  #NAMESPACE_ENTER "$BUILDLOCATION"/debootstrap/debootstrap --arch "$BUILDARCH" vivid "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2 http://archive.ubuntu.com/ubuntu
  NAMESPACE_ENTER "$BUILDLOCATION"/debootstrap/debootstrap --arch "$BUILDARCH" stretch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2 http://httpredir.debian.org/debian
  debootstrapresult=$?
  if [[ $debootstrapresult == 0 ]]
  then
    touch "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
  fi
fi

#Kill the namespace's PID 1
kill -9 $ROOTPID