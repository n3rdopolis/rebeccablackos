#! /usr/bin/sudo /bin/bash
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
  

SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

export BUILDLOCATION=~/RBOS_Build_Files
mkdir -p "$BUILDLOCATION"

#####Tell User what script does
echo "
NOTE THAT THE FOLDERS LISTED BELOW ARE DELETED OR OVERWRITTEN ALONG WITH THE CONTENTS (file names are case sensitive)
    
   Folder:            $BUILDLOCATION
   File:              ${HOME}/RebeccaBlackLinux_i386.iso or ${HOME}/RebeccaBlackLinux_amd64.iso
   File:              ${HOME}/RebeccaBlackLinux_DevDbg_i386.iso or ${HOME}/RebeccaBlackLinux_DevDbg_amd64.iso
   File:              ${HOME}/RebeccaBlackLinux_Revisions_i386.txt or ${HOME}/RebeccaBlackLinux_Revisions_amd64.txt
"





echo "PLEASE READ ALL TEXT ABOVE. YOU CAN SCROLL BY USING SHIFT-PGUP or SHIFT-PGDOWN (OR THE SCROLL WHEEL OR SCROLL BAR IF AVALIBLE) AND THEN PRESS ENTER TO CONTINUE..."

echo "Select Arch. Enter 1 for i386, 2 for amd64. Default=i386."
read archselect
if [[ $archselect == 2 ]]
then
  export BUILDARCH=amd64
else
  export BUILDARCH=i386
fi

echo "If you want to build revisions specified in a list file from a previous build, copy the file to "$BUILDLOCATION"/RebeccaBlackLinux_Revisions_$BUILDARCH.txt Ensure the file is copied, and not moved, as it is treated as a one time control file, and deleted after the next run."
echo "Most users can ignore this message. Press Enter to continue..."
read a

STARTTIME=$(date +%s)

#prepare debootstrap
if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap || ! -e "$BUILDLOCATION"/DontDownloadDebootstrapScript ]]
then
  touch "$BUILDLOCATION"/DontDownloadDebootstrapScript
  mkdir -p "$BUILDLOCATION"/debootstrap
  FTPFILELIST=$(ftp -n -v ftp.debian.org << EOT
ascii
user anonymous " "
prompt
cd debian/pool/main/d/debootstrap/
ls 
bye
EOT)
  FTPFILE=$(echo "$FTPFILELIST" | awk '{print $9}' | grep tar| tail -1)
  wget http://ftp.debian.org/debian/pool/main/d/debootstrap/$FTPFILE -O "$BUILDLOCATION"/debootstrap/debootstrap.tar.gz
  tar xaf "$BUILDLOCATION"/debootstrap/debootstrap.tar.gz -C "$BUILDLOCATION"/debootstrap --strip 1
  make -C "$BUILDLOCATION"/debootstrap/ devices.tar.gz
fi

#If debootstrap fails
if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap ]]
then 
  echo "Download of debootstrap failed, this script needs to be able to download debootstrap from ftp.debian.org in order to be able to continue."
  exit 1
fi

#get the size of the users home file system. 
FreeSpace=$(df ~ | awk '{print $4}' |  grep -v Av)
#if there is 25gb or less tell the user and quit. If not continue.
if [[ $FreeSpace -le 25000000 ]] 
then
  echo "You have less then 25gb of free space on the partition that contains your home folder. Please free up some space." 
  echo "The script will now abort."
  echo "free space:"
  df ~ -h | awk '{print $4}' |  grep -v Av
  exit 1                       
fi


chmod +x "$SCRIPTFOLDERPATH"/externalbuilders/*

echo "Setting up live system..."

REBUILT="to update"

#This function unmounts all known mountpoints created by all of the scripts in externalbuilders
function UnmountAll()
{
#unmount the chrooted procfs from the outside 
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/dev

#unmount the external archive folder
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/var/cache/apt/archives
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/phase_1/var/cache/apt/archives
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/phase_2/var/cache/apt/archives

#unmount the debs data
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild/buildoutput

#unmount the source download folder
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/srcbuild

#unmount the cache /var/tmp folder
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/var/tmp

#unmount the cache /var/tmp folder
umount -lf "$BUILDLOCATION"/build/$BUILDARCH/workdir/home/remastersys

#unmount the FS at the workdir and phase 2
umount -lfd "$BUILDLOCATION"/build/$BUILDARCH/workdir
umount -lfd "$BUILDLOCATION"/build/$BUILDARCH/phase_2

#Terminate processess using files in the build folder for the architecture
lsof -t +D "$BUILDLOCATION"/build/$BUILDARCH |while read PID 
do 
kill -9 $PID
done
}


UnmountAll

#Delete buildoutput based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartBuildoutput$BUILDARCH ]]
then
  rm -rf "$BUILDLOCATION"/build/$BUILDARCH/buildoutput
  mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/buildoutput
  touch "$BUILDLOCATION"/DontRestartBuildoutput$BUILDARCH
fi

#Delete archives based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartArchives$BUILDARCH ]]
then
  rm -rf "$BUILDLOCATION"/build/$BUILDARCH/archives
  mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/archives
  touch "$BUILDLOCATION"/DontRestartArchives$BUILDARCH
fi

#Only run phase0 if phase1 and phase2 are going to be reset. phase0 only resets 
if [[ ! -f "$BUILDLOCATION"/DontStartFromScratch$BUILDARCH || ! -f "$BUILDLOCATION"/DontRestartPhase1$BUILDARCH || ! -f "$BUILDLOCATION"/DontRestartPhase2$BUILDARCH ]]
then
  #if set to rebuild phase 1
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase1$BUILDARCH ]
  then
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_1/*
  fi

  #if set to rebuild phase 2
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase2$BUILDARCH ]
  then
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_2/*
    mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/phase_2/tmp
    touch "$BUILDLOCATION"/build/$BUILDARCH/phase_2/tmp/INSTALLS.txt.bak
  fi

  if [ ! -f "$BUILDLOCATION"/DontStartFromScratch$BUILDARCH ]
  then
    #clean up old files
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_1
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_2
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_3
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/workdir
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/importdata
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/vartmp
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/remastersys
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/buildoutput
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/archives
    rm -rf "$BUILDLOCATION"/build/$BUILDARCH/srcbuild
    rm "$BUILDLOCATION"/DontRestartPhase1$BUILDARCH
    rm "$BUILDLOCATION"/DontRestartPhase2$BUILDARCH
    touch "$BUILDLOCATION"/DontStartFromScratch$BUILDARCH
    mkdir -p "$BUILDLOCATION"/build/$BUILDARCH/phase_2/tmp
    touch "$BUILDLOCATION"/build/$BUILDARCH/phase_2/tmp/INSTALLS.txt.bak
    REBUILT="to rebuild from scratch"
  fi
  "$SCRIPTFOLDERPATH"/externalbuilders/rebeccablacklinux_phase0.sh
fi

#run the build scripts
UnmountAll
"$SCRIPTFOLDERPATH"/externalbuilders/rebeccablacklinux_phase1.sh 
UnmountAll
"$SCRIPTFOLDERPATH"/externalbuilders/rebeccablacklinux_phase2.sh  
UnmountAll
"$SCRIPTFOLDERPATH"/externalbuilders/rebeccablacklinux_phase3.sh 
UnmountAll


echo "CLEANUP PHASE 3"  

#Clean up Phase 3 data.
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/phase_3/*
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/vartmp
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/remastersys
rm -rf "$BUILDLOCATION"/build/$BUILDARCH/importdata
"$SCRIPTFOLDERPATH"/externalbuilders/cleanup_srcbuild.sh
UnmountAll

ENDTIME=$(date +%s)
echo "build finished in $((ENDTIME-STARTTIME)) seconds $REBUILT"