#! /usr/bin/sudo /bin/bash
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

export BUILDLOCATION=~/RBOS_Build_Files
mkdir -p "$BUILDLOCATION"
echo "Build script for RebeccaBlackOS. The build process requires no user interaction, apart from specifing the build architecture, and sending a keystroke to confirm to starting the build process.



"

export BUILDARCH=$(echo $1| awk -F = '{print $2}')
if [[ -z "$BUILDARCH" ]]
then
  echo "Select Arch. Enter 1 for i386, 2 for amd64, 3 for custom. Default=i386."
  echo "The arch can also be selected by passing BUILDARCH=(architecture) as the first argument."
  read archselect
  if [[ $archselect == 2 ]]
  then
    export BUILDARCH=amd64
  elif [[ $archselect == 3 ]]
  then
    echo "Enter custom CPU arch. Please ensure your processor is capable of running the selected architecture."
    read BUILDARCH
    export BUILDARCH
  else
    export BUILDARCH=i386
  fi
else 
  SKIPPROMPT=1
fi

#Create the placeholder for the revisions import, so that it's easy for the user to get the name correct. It is only used if it's more than 0 bytes
if [[ ! -e "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt ]]
then
  touch "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt
fi

#####Tell User what script does
echo "
NOTE THAT THE FOLDERS LISTED BELOW ARE DELETED OR OVERWRITTEN ALONG WITH THE CONTENTS (file names are case sensitive)
    
   Folder:            $BUILDLOCATION
   File:              ${HOME}/RebeccaBlackOS_"$BUILDARCH".iso
   File:              ${HOME}/RebeccaBlackOS_DevDbg_"$BUILDARCH".iso
   File:              ${HOME}/RebeccaBlackOS_Revisions_"$BUILDARCH".txt
   File:              ${HOME}/RebeccaBlackOS_Source_"$BUILDARCH".tar.gz
"

echo "PLEASE READ ALL TEXT ABOVE. YOU CAN SCROLL BY USING SHIFT-PGUP or SHIFT-PGDOWN (OR THE SCROLL WHEEL OR SCROLL BAR IF AVALIBLE) AND THEN PRESS ENTER TO CONTINUE..."



echo "If you want to build revisions specified in a list file from a previous build, overwrite "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt with the requested revisions file generated from a previous build, or a downloaded instance. 

Although the files have the CPU architecture as the suffix in the file name, there is nothing CPU dependant in them, and the suffix only exists to identify them. 
For example RebeccaBlackOS_Revisions_amd64.txt can be used in "$BUILDLOCATION"/RebeccaBlackOS_Revisions_i386.txt 

Ensure the file is copied, and not moved, as it is treated as a one time control file, and deleted after the next run."


if [[ $SKIPPROMPT != 1 ]]
then
  echo "Most users can ignore this message. Press Enter to continue..."
  read wait
else
  echo "Most users can ignore this message. The build process will start in 5 seconds"
  sleep 5
fi
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
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/dev

#unmount the chrooted /run/shm from the outside 
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/run/shm

#unmount the external archive folder
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/cache/apt/archives
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/var/cache/apt/archives
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/var/cache/apt/archives

#unmount the debs data
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild/buildoutput

#unmount the source download folder
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/srcbuild

#unmount the cache /var/tmp folder
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/var/tmp

#unmount the cache /var/tmp folder
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/home/remastersys

#unmount the FS at the workdir and phase 2
umount -lfd "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
umount -lfd "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2

#Terminate processess using files in the build folder for the architecture
lsof -t +D "$BUILDLOCATION"/build/"$BUILDARCH" |while read PID 
do 
kill -9 $PID
done
}


UnmountAll

#Delete buildoutput based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH" ]]
then
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
  touch "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH"
fi

#Delete archives based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH" ]]
then
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/archives
  touch "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH"
fi

#Delete downloaded source based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH" ]]
then
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild
  touch "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH"
fi

#Only run phase0 if phase1 and phase2 are going to be reset. phase0 only resets 
if [[ ! -f "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH" || ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" || ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]]
then
  #if set to rebuild phase 1
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" ]
  then
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/*
  fi

  #if set to rebuild phase 2
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]
  then
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/*
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.bak
  fi

  if [ ! -f "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH" ]
  then
    #clean up old files
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild
    rm "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
    rm "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
    touch "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH"
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.bak
    REBUILT="to rebuild from scratch"
  fi
  "$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase0.sh
  UnmountAll
fi

#run the build scripts
"$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase1.sh 
UnmountAll
"$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase2.sh  
UnmountAll
"$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase3.sh 
UnmountAll


echo "CLEANUP PHASE 3"  

#Clean up Phase 3 data.
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/
"$SCRIPTFOLDERPATH"/externalbuilders/cleanup_srcbuild.sh
UnmountAll

ENDTIME=$(date +%s)
echo "build finished in $((ENDTIME-STARTTIME)) seconds $REBUILT"