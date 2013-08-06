#! /usr/bin/sudo /bin/bash
#    Copyright (c) 2012, nerdopolis (or n3rdopolis) <bluescreen_avenger@version.net>
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
ThIsScriPtSFolDerLoCaTion=$(dirname "$SCRIPTFILEPATH")

RBOSLOCATION=~/RBOS_Build_Files

#####Tell User what script does
echo "
THIS SCRIPT INSTALLS debootstrap AND aufs-tools on the build host (this computer)

This requires Ubuntu Quantal or later due to the use of overlayfs

NOTE THAT THE FOLDERS LISTED BELOW ARE DELETED OR OVERWRITTEN ALONG WITH THE CONTENTS (file names are case sensitive)
    
   Folder:            ${HOME}/RBOS_Build_Files/
   File:              ${HOME}/RebeccaBlackLinux_i386.iso or ${HOME}/RebeccaBlackLinux_amd64.iso
   File:              ${HOME}/RebeccaBlackLinux_Reduced_i386.iso or ${HOME}/RebeccaBlackLinux_Reduced_amd64.iso
"





echo "PLEASE READ ALL TEXT ABOVE. YOU CAN SCROLL BY USING SHIFT-PGUP or SHIFT-PGDOWN (OR THE SCROLL WHEEL OR SCROLL BAR IF AVALIBLE) AND THEN PRESS ENTER TO CONTINUE..."

read a

echo "Select Arch. Enter 1 for i386, 2 for amd64. Default=i386."
read archselect
if [[ $archselect == 2 ]]
then
export BUILDARCH=amd64
else
export BUILDARCH=i386
fi

STARTTIME=$(date +%s)

#install needed tools to get the build system to work
apt-get install debootstrap aufs-tools

if [[ ! -f /usr/sbin/debootstrap ]]
then 
echo "debootstrap install apparently failed."
exit
fi

if [[ ! -f /sbin/mount.aufs || ! -f /lib/modules/$(uname -r)/kernel/ubuntu/aufs/aufs.ko ]]
then 
echo "aufs install apparently failed."
exit
fi

#get the size of the users home file system. 
HomeFileSysTemFSFrEESpaCe=$(df ~ | awk '{print $4}' |  grep -v Av)
#if there is 12gb or less tell the user and quit. If not continue.
if [[ $HomeFileSysTemFSFrEESpaCe -le 12000000 ]] 
  then               
  echo "You have less then 12gb of free space on the partition that contains your home folder. Please free up some space." 
  echo "The script will now abort."
  echo "free space:"
  df ~ -h | awk '{print $4}' |  grep -v Av
  exit 1                       
fi


chmod +x $ThIsScriPtSFolDerLoCaTion/externalbuilders/*

echo "Setting up live system..."

REBUILT="to update"


#only initilize the FS if the FS isn't there.
if [ ! -f $RBOSLOCATION/DontStartFromScratch$BUILDARCH ]
then
$ThIsScriPtSFolDerLoCaTion/externalbuilders/rebeccablacklinux_phase0.sh
REBUILT="to rebuild from scratch"
fi

#run the build scripts
$ThIsScriPtSFolDerLoCaTion/externalbuilders/rebeccablacklinux_phase1.sh 
$ThIsScriPtSFolDerLoCaTion/externalbuilders/rebeccablacklinux_phase2.sh  
$ThIsScriPtSFolDerLoCaTion/externalbuilders/rebeccablacklinux_phase3.sh 

ENDTIME=$(date +%s)
echo "build finished in $((ENDTIME-STARTTIME)) seconds $REBUILT"