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
echo "PHASE 0"
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

#Initilize the two systems, Phase1 is the download system, for filling  "$BUILDLOCATION"/build/"$BUILDARCH"/archives and  "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild, and phase2 is the base of the installed system
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/archives
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/archives
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt/archives
mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/archives "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt/archives

#If using a revisions file, force downloading a snapshot from the time specified
if [[ -e "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt ]]
then
  #add
  #--keyring /usr/share/keyrings/debian-archive-removed-keys.gpg
  #to debootstrap if in the future building a snapshot, and debootstrap fails with 'Release signed by unknown key'
  APTFETCHDATE=$(grep APTFETCHDATE= "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt | head -1 | sed 's/APTFETCHDATE=//g')
  DEBIANREPO="http://snapshot.debian.org/archive/debian/$APTFETCHDATE/"
else
  DEBIANREPO="http://httpredir.debian.org/debian"
fi

#Set the debootstrap dir
export DEBOOTSTRAP_DIR="$BUILDLOCATION"/debootstrap

#setup a really basic Debian installation for downloading 
#if set to rebuild phase 1
if [ ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" ]
then
  echo "Setting up chroot for downloading archives and software..."
  "$BUILDLOCATION"/debootstrap/debootstrap --arch "$BUILDARCH" stretch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1 $DEBIANREPO
  debootstrapresult=$?
  if [[ $debootstrapresult == 0 ]]
  then
    touch "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
  fi
fi

#if set to rebuild phase 1
if [ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]
then
  #Force phase1 to rehandle downloads if phase2 is reset
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]
  then
    rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/INSTALLS.txt.downloadbak
    rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/FAILEDDOWNLOADS.txt
    rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/INSTALLSSTATUS.txt
  fi

  #setup a really basic Debian installation for the live cd
  echo "Setting up chroot for the Live CD..."
  "$BUILDLOCATION"/debootstrap/debootstrap --arch "$BUILDARCH" stretch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2 $DEBIANREPO
  debootstrapresult=$?
  if [[ $debootstrapresult == 0 ]]
  then
    touch "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
  fi
fi


#If using a revisions file for this pass, mark the chroot targets to be rebuilt
if [[ -e "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt ]]
then
  rm "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
  rm "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
fi
