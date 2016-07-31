#! /usr/bin/sudo /bin/bash
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

#unset most varaibles, except PATH and WAYLAND_HOST and WAYLAND_GUEST
while read var
do 
  unset "$var"
done < <(env | awk -F = '{print $1}' | grep -Ev "^PATH$|^HOME$" ) 
export TERM=linux
PATH=$(getconf PATH):/sbin:/usr/sbin
export LANG=en_US.UTF-8

  
#If user presses CTRL+C, kill any namespace, remove the lock file, exit the script
trap 'kill -9 $ROOTPID; rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile; exit' 2

#Function to start all arguments as a command in a seperate PID and mount namespace
function NAMESPACE_EXECUTE {
  #Create the PID and Mount namespaces to start the command in
  unshare -f --pid --mount --mount-proc $@ &
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
  if [[ -z $ROOTPID ]]
  then
    echo "The main namespace process failed to start, in 1 minute. This should not take that long"
    exit
  fi
  
  #Wait for the PID to complete
  wait $UNSHAREPID
}


SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

export BUILDLOCATION=~/RBOS_Build_Files

#make a folder containing the live cd tools in the users local folder
mkdir -p "$BUILDLOCATION"

#switch to that folder
cd "$BUILDLOCATION"

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


#Detect another instance, by creating a testing a lockfile, which is a symlink to /proc/pid/cmdline, and making sure the second line of /proc/pid/cmdline matches (as it's the path to the script).
ls $(readlink -f "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile) &> /dev/null
result=$?
if [[ $result != 0 || ! -e "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile  ]]
then
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile &> /dev/null
  "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile 2>/dev/null
  ln -s /proc/"$$"/cmdline "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile
else
  echo "Error: Another instance is already running for $BUILDARCH"
  exit
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



echo "If you want to build revisions specified in a list file from a previous build, overwrite 

     "$BUILDLOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt 

with the requested revisions file generated from a previous build, or a downloaded instance. 

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
  echo "Control file for debootstrap removed, or non existing. Deleting downloaded debootstrap folder"
  touch "$BUILDLOCATION"/DontDownloadDebootstrapScript
  rm -rf "$BUILDLOCATION"/debootstrap
  rm "$BUILDLOCATION"/debootstrap/debootstrap.tar.gz
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

echo "Starting the build process..."

REBUILT="to update"

#Delete buildoutput based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH" ]]
then
  echo "Control file for buildoutput removed, or non existing. Deleting compiled .deb files for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
  touch "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH"
fi

#Delete archives based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH" ]]
then
  echo "Control file for archives removed, or non existing. Deleting downloaded cached .deb files for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/archives
  touch "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH"
fi

#Delete downloaded source based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH" ]]
then
  echo "Control file for srcbuild removed, or non existing. Deleting downloaded sources for $BUILDARCH"
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
    echo "Control file for phase_1 removed, or non existing. Deleting phase_1 system for $BUILDARCH"
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/*
  fi

  #if set to rebuild phase 2
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]
  then
    echo "Control file for phase_2 removed, or non existing. Deleting phase_2 system for $BUILDARCH"
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/*
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.installbak
  fi

  if [ ! -f "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH" ]
  then
    echo "Control file for all of $BUILDARCH removed, or non existing. Deleting phase_1, phase_2, archives, built deb files, and downloaded sources"
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
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.installbak
    REBUILT="to rebuild from scratch"
  fi
  NAMESPACE_EXECUTE "$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase0.sh
fi

#run the build scripts
NAMESPACE_EXECUTE "$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase1.sh 
NAMESPACE_EXECUTE "$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase2.sh
NAMESPACE_EXECUTE "$SCRIPTFOLDERPATH"/externalbuilders/rebeccablackos_phase3.sh 


echo "CLEANUP PHASE 3"  

#Clean up Phase 3 data.
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/
NAMESPACE_EXECUTE "$SCRIPTFOLDERPATH"/externalbuilders/cleanup_srcbuild.sh
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata

rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile 

ENDTIME=$(date +%s)
echo "build of $BUILDARCH finished in $((ENDTIME-STARTTIME)) seconds $REBUILT"