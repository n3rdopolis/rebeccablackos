#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016, 2017 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#This function echo's the specified text, which is also written to a log
function echolog
{
  LOGTEXTADD=$(echo "$@")
  LOGTEXT+=$LOGTEXTADD
  if [[ $1 != -n ]]
  then
    LOGTEXT+=$'\n'
  fi
  echo "$@"
}

function faillog
{
  echolog "$@"

  echo "$LOGTEXT" > "$BUILDLOCATION"/logs/failedlogs/Failed_"$STARTDATE".log
  rm "$BUILDLOCATION"/logs/failedlogs/latest-failedlog.log 2>/dev/null
  ln -s "$BUILDLOCATION"/logs/failedlogs/Failed_"$STARTDATE".log "$BUILDLOCATION"/logs/failedlogs/latest-failedlog.log
  exit 1
}

function setup_buildprocess
{
  #unset most varaibles
  while read var
  do 
    unset "$var" &> /dev/null
  done < <(env | awk -F = '{print $1}' | grep -Ev "^PATH$|^HOME$|^SUDO_USER$" ) 
  export TERM=linux
  PATH=$(getconf PATH):/sbin:/usr/sbin
  export LANG=en_US.UTF-8
  STARTDATE=$(date +"%Y-%m-%d_%H-%M-%S")

  #If user presses CTRL+C, kill any namespace, remove the lock file, exit the script
  trap 'if [[ $BUILD_RUNNING == 0 ]]; then exit; fi; if [[ -e /proc/"$ROOTPID" && $ROOTPID != "" ]]; then kill -9 $ROOTPID; rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile; exit 2; fi' 2

}

#Function to start all arguments, past the second one, as a command in a seperate PID and mount namespace. The first argument determines if the namespace should have network connectivity or not (1 = have network connectivity, 0 = no network connectivity)
function NAMESPACE_EXECUTE {
  HASNETWORK=$1
  shift

  if [[ $HASNETWORK == 0 ]]
  then
    UNSHAREFLAGS="-f --pid --mount --net --mount-proc"
  else
    UNSHAREFLAGS="-f --pid --mount --mount-proc"
  fi

  #Create the PID and Mount namespaces to start the command in
  unshare $UNSHAREFLAGS $@ &
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
    faillog "The main namespace process failed to start, in 1 minute. This should not take that long"
  fi
  
  #Wait for the PID to complete
  wait $UNSHAREPID
}

#Declare most of the script as a function, to protect against the script from any changes when running, from causing the build process to be inconsistant
function run_buildprocess {
BUILD_RUNNING=0

SCRIPTFILEPATH=$(readlink -f "$0")
SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

#Begin config options
HOMELOCATION=$HOME
export BUILDLOCATION="$HOMELOCATION"/RBOS_Build_Files
export BUILDUNIXNAME=rebeccablackos
export BUILDFRIENDLYNAME=RebeccaBlackOS

#Create the logs folder for any logs the script may need to write if it aborts early
mkdir -p "$BUILDLOCATION"/logs/failedlogs

HASOVERLAYFS=$(grep -c overlay$ /proc/filesystems)
if [[ $HASOVERLAYFS == 0 ]]
then
  HASOVERLAYFSMODULE=$(modprobe -n overlay; echo $?)
  if [[ $HASOVERLAYFSMODULE == 0 ]]
  then
    HASOVERLAYFS=1
  else
    faillog "Building without overlayfs is no longer supported"
  fi
fi

#Values for determining how much free disk/ramdisk space is needed
STORAGESIZE_TOTALSIZE=0
STORAGESIZE_PADDING=$((2 * 1048576 ))

STORAGESIZE_TMPBASEBUILD=$((1 * 1048576 ))
STORAGESIZE_TMPSRCBUILDOVERLAY=$((2 * 1048576 ))
STORAGESIZE_TMPSRCBUILDOFULL=$((11 * 1048576 ))
STORAGESIZE_TMPPHASE3=$((2 * 1048576 ))
STORAGESIZE_TMPREMASTERSYS=$((6 * 1048576 ))


STORAGESIZE_ISOOUT=$((4 * 1048576 ))
STORAGESIZE_BUILDOUTPUT=$((2 * 1048576 ))
STORAGESIZE_PHASE1=$((2 * 1048576 ))
STORAGESIZE_PHASE2=$((4 * 1048576 ))
STORAGESIZE_ARCHIVES=$((1 * 1048576 ))
STORAGESIZE_SRCBUILD=$((25 * 1048576 ))
#End config options

#make a folder containing the live cd tools in the users local folder
mkdir -p "$BUILDLOCATION"

#switch to that folder
cd "$BUILDLOCATION"

echolog "Build script for "$BUILDFRIENDLYNAME". The build process requires no user interaction, apart from specifing the build architecture, and sending a keystroke to confirm to starting the build process.


"

export BUILDARCH=$(echo $1| awk -F = '{print $2}')
if [[ -z "$BUILDARCH" ]]
then
  echolog "Select Arch. Enter 1 for i386, 2 for amd64, 3 for custom. Default=i386."
  echolog "The arch can also be selected by passing BUILDARCH=(architecture) as the first argument."
  read archselect
  if [[ $archselect == 2 ]]
  then
    export BUILDARCH=amd64
  elif [[ $archselect == 3 ]]
  then
    echolog "Enter custom CPU arch. Please ensure your processor is capable of running the selected architecture."
    read BUILDARCH
    export BUILDARCH
  else
    export BUILDARCH=i386
  fi
  SKIPPROMPT=0
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
  faillog "Error: Another instance is already running for $BUILDARCH"
fi

#Create the placeholder for the revisions import, so that it's easy for the user to get the name correct. It is only used if it's more than 0 bytes
if [[ ! -e "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt ]]
then
  touch "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt
fi

#Create the placeholder for the list of packages to delete
if [[ ! -e "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt ]]
then
  touch "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt
fi

#####Tell User what script does
echolog "
The following files will be generated by the script. The listed files will be overwritten. (file names and folder names are case sensitive)
    
   Folder:            $BUILDLOCATION
   File:              ${HOMELOCATION}/"$BUILDFRIENDLYNAME"_"$BUILDARCH".iso
   File:              ${HOMELOCATION}/"$BUILDFRIENDLYNAME"_DevDbg_"$BUILDARCH".iso
   File:              ${HOMELOCATION}/"$BUILDFRIENDLYNAME"_Revisions_"$BUILDARCH".txt
   File:              ${HOMELOCATION}/"$BUILDFRIENDLYNAME"_Source_"$BUILDARCH".tar.gz
"

echolog "----------------------------------------------------------------------------------------

If you want to build revisions specified in a list file from a previous build, overwrite 

     "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt 

with the requested revisions file generated from a previous build, or a downloaded instance. 


You may also specify a list of pacakges in

     "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt 

to batch restart, one package per line.


Although the files have the CPU architecture as the suffix in the file name, there is nothing CPU dependant in them, and the suffix only exists to identify them. 
For example buildcore_revisions_amd64.txt can be used in "$BUILDLOCATION"/buildcore_revisions_i386.txt 
and
RestartPackageList_amd64.txt can be used in RestartPackageList_i386.txt

Ensure the file(s) are copied, and not moved, as they are treated as a one time control file, and deleted after the next run.
-----------------------------------------------------------------------------------------------------------------------------"


if [[ $SKIPPROMPT != 1 ]]
then
  echolog "Most users can ignore this message. Press Enter to continue..."
  read wait
else
  echolog "Most users can ignore this message. The build process will start in 5 seconds"
  sleep 5
fi
STARTTIME=$(date +%s)
PREPARE_STARTTIME=$(date +%s)

#prepare debootstrap
if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap || ! -e "$BUILDLOCATION"/DontDownloadDebootstrapScript ]]
then
  echolog "Control file for debootstrap removed, or non existing. Deleting downloaded debootstrap folder"
  touch "$BUILDLOCATION"/DontDownloadDebootstrapScript
  rm -rf "$BUILDLOCATION"/debootstrap/*
  rm "$BUILDLOCATION"/debootstrap/debootstrap.tar.gz
  mkdir -p "$BUILDLOCATION"/debootstrap
  DEBOOTSTRAPURL=$(wget  -O -  http://packages.debian.org/source/sid/debootstrap 2>/dev/null|grep .tar.gz | awk -F \" '{print $2}')
  wget "$DEBOOTSTRAPURL" -O "$BUILDLOCATION"/debootstrap/debootstrap.tar.gz
  tar xaf "$BUILDLOCATION"/debootstrap/debootstrap.tar.gz -C "$BUILDLOCATION"/debootstrap --strip 1
  make -C "$BUILDLOCATION"/debootstrap/ devices.tar.gz
fi

#If debootstrap fails
if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap ]]
then 
  faillog "Download of debootstrap failed, this script needs to be able to download debootstrap from ftp.debian.org in order to be able to continue."
fi

#Determine how much free disk space is neeed
((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PADDING))

#Determine how much space is in use by the ISOs already, and take that value away from the space allocated towards the output ISO, and append it
CURRENT_ISOOUT=$(du -c "$HOMELOCATION"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso 2>/dev/null | tail -1 | awk '{print $1}')
((STORAGESIZE_TOTALSIZE+=(STORAGESIZE_ISOOUT-CURRENT_ISOOUT)))

echolog "Starting the build process..."

REBUILT="to update"

#Delete any stale files
echolog "Cleaning up any stale remaining files from any incomplete build..."
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/sourcehome/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/config/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay/*

#Only run phase0 if phase1 and phase2 are going to be reset. phase0 only resets
RUN_PHASE_0=0
if [[ ! -f "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH" || ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" || ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]]
then
  #If set to clean up all files
  if [ ! -f "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH" ]
  then
    echolog "Control file for all of $BUILDARCH removed, or non existing. Deleting phase_1, phase_2, archives, built deb files, and downloaded sources"
    #clean up old files
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/*
    rm "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
    rm "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
    rm "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH"
    rm "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH"
    rm "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH"
    touch "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH"
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.installbak
    REBUILT="to rebuild from scratch"
  fi

  #if set to rebuild phase 1
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" ]
  then
    echolog "Control file for phase_1 removed, or non existing. Deleting phase_1 system for $BUILDARCH"
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/*
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PHASE1))
  fi

  #if set to rebuild phase 2
  if [ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" ]
  then
    echolog "Control file for phase_2 removed, or non existing. Deleting phase_2 system for $BUILDARCH"
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/*
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.installbak
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PHASE2))
  fi
  RUN_PHASE_0=1
fi

#Delete buildoutput based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH" ]]
then
  echolog "Control file for buildoutput removed, or non existing. Deleting compiled .deb files for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput/*
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
  touch "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH"
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_BUILDOUTPUT))
fi

#Delete archives based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH" ]]
then
  echolog "Control file for archives removed, or non existing. Deleting downloaded cached .deb files for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives/*
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/archives
  touch "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH"

  #Force phase_1 to rehandle downloads
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/INSTALLS.txt.downloadbak
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/FAILEDDOWNLOADS.txt
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_ARCHIVES))
fi

#Delete downloaded source based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH" ]]
then
  echolog "Control file for srcbuild removed, or non existing. Deleting downloaded sources for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/*
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild
  touch "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH"
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_SRCBUILD))
fi

#create the folders for the build systems, and for any folder that will be bind mounted in
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildoutput
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/workdir
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/archives
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/importdata
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/unionwork
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/unionwork_srcbuild
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk

FREERAM=$(grep MemAvailable: /proc/meminfo | awk '{print $2}')

RAMDISKSIZE=0
#Determine the size of the ram disk, determine if enough free ram for base in ramdisk
RAMDISKTESTSIZE=$((STORAGESIZE_TMPBASEBUILD))
if [[ $FREERAM -gt $((STORAGESIZE_PADDING+RAMDISKTESTSIZE)) ]]
then
  RAMDISK_FOR_BASE=1
  RAMDISKSIZE=$RAMDISKTESTSIZE
else
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPBASEBUILD))
fi

#Determine if enough free RAM for srcbuild_overlay in ramdisk
RAMDISKTESTSIZE=$((STORAGESIZE_TMPBASEBUILD+STORAGESIZE_TMPSRCBUILDOVERLAY))
if [[ $FREERAM -gt $((STORAGESIZE_PADDING+RAMDISKTESTSIZE)) ]]
then
  RAMDISK_FOR_SRCBUILD=1
  RAMDISKSIZE=$RAMDISKTESTSIZE
else
  if [[ $HASOVERLAYFS == 1 ]]
  then
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPSRCBUILDOVERLAY))
  else
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPSRCBUILDOFULL))
  fi
fi

#Determine if enough free RAM for phase3 in ramdisk
RAMDISKTESTSIZE=$((STORAGESIZE_TMPBASEBUILD+STORAGESIZE_TMPSRCBUILDOVERLAY+STORAGESIZE_TMPPHASE3))
if [[ $FREERAM -gt $((STORAGESIZE_PADDING+RAMDISKTESTSIZE)) ]]
then
  RAMDISK_FOR_PHASE3=1
  RAMDISKSIZE=$RAMDISKTESTSIZE
else
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPPHASE3))
fi

#Determine if enough free RAM for Remastersys in ramdisk
RAMDISKTESTSIZE=$((STORAGESIZE_TMPBASEBUILD+STORAGESIZE_TMPSRCBUILDOVERLAY+STORAGESIZE_TMPPHASE3+STORAGESIZE_TMPREMASTERSYS))
if [[ $FREERAM -gt $((STORAGESIZE_PADDING+RAMDISKTESTSIZE)) ]]
then
  RAMDISK_FOR_REMASTERSYS=1
  RAMDISKSIZE=$RAMDISKTESTSIZE
else
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPREMASTERSYS))
fi

#get the size of the users home file system.
FREEDISKSPACE=$(df --output=avail $HOMELOCATION | tail -1)
#if there is less than the required amount of space, then exit.
if [[ $FREEDISKSPACE -le $STORAGESIZE_TOTALSIZE ]]
then
  echolog "You have less then $(( ((STORAGESIZE_TOTALSIZE+1023) /1024 + 1023) /1024 ))GB of free space on the filesystem $(df --output=target $HOMELOCATION | tail -1) for $BUILDLOCATION. Please free up some space."
  echolog "The script will now abort."
  faillog "free space: $FREEDISKSPACE"
else
  echolog -e "\n\nRam disk maximum size: $(( ((RAMDISKSIZE+1023) /1024 + 1023) /1024 ))GB, Free disk space needed: $(( ((STORAGESIZE_TOTALSIZE+1023) /1024 + 1023) /1024 ))GB, Free Space: $(( ((FREEDISKSPACE+1023) /1024 + 1023) /1024 ))GB\n"
  sleep 1
fi

#Mount the ramdisk
mount --make-rprivate /
if [[ $RAMDISK_STATUS != 0 ]]
then
  mount -t tmpfs -o size=${RAMDISKSIZE}k tmpfs "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk
  RAMDISK_STATUS=$?
else
  RAMDISK_STATUS=1
fi

#Create the folders in the ramdisk
if [[ $RAMDISK_FOR_BASE == 1 && $RAMDISK_STATUS == 0 ]]
then
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/buildlogs
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/vartmp
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/importdata
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/externalbuilders
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/exportsource
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/buildlogs "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/vartmp "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/importdata "$BUILDLOCATION"/build/"$BUILDARCH"/importdata
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/externalbuilders "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/exportsource "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource
fi

if [[ $RAMDISK_FOR_SRCBUILD == 1 && $RAMDISK_STATUS == 0 ]]
then
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/srcbuild_overlay
fi
if [[ $RAMDISK_FOR_PHASE3 == 1 && $RAMDISK_STATUS == 0 ]]
then
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork_srcbuild
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/phase_3
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/phase_3 "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3
fi
if [[ $RAMDISK_FOR_REMASTERSYS == 1 && $RAMDISK_STATUS == 0 ]]
then
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/remastersys
  mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/remastersys "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
fi


#Copy external builders into thier own directory, make them executable
cp "$SCRIPTFOLDERPATH"/externalbuilders/* "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders
chmod +x "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/*

#Copy all external files before they are used
rsync "$SCRIPTFOLDERPATH"/"$BUILDUNIXNAME"_files/* -CKr "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
rsync "$SCRIPTFOLDERPATH"/* -CKr "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource

#Support importing the control file to use fixed revisions of the source code
rm "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt > /dev/null 2>&1
rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/tmp/buildcore_revisions.txt > /dev/null 2>&1
rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/buildcore_revisions.txt > /dev/null 2>&1
rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/tmp/buildcore_revisions.txt > /dev/null 2>&1
if [ -s "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt ]
then
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/
  cp "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt
  rm "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt
  touch "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt
fi

#Delete the list of pacakges specified in RestartPackageList_"$BUILDARCH".txt
cat "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt | while read RESETPACKAGE
do
  #Dont allow path tampering, stop at the first / for path.
  IFS=/
  RESETPACKAGE=($RESETPACKAGE)
  unset IFS
  RESETPACKAGE=${RESETPACKAGE[0]}

  #Delete the file, don't allow path clobbering for the current directory, or parent directory. rm doesnt delete directories by default, but be paranoid anyway
  if [[ ! -z $RESETPACKAGE  && $RESETPACKAGE != '.' && $RESETPACKAGE != '..' ]]
  then
    rm "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput/control/"$RESETPACKAGE"
    echolog "       Marked package: $RESETPACKAGE for rebuild."
  fi
done
echo -n > "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt

#make the imported files executable 
chmod 0755 -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
chown  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
chgrp  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/

PREPARE_ENDTIME=$(date +%s)

BUILD_RUNNING=1
#run the build scripts
if [[ $RUN_PHASE_0 == 1 ]]
then
  PHASE0_STARTTIME=$(date +%s)
  echolog "Starting phase0 (logged in phase0.log )..."
  NAMESPACE_EXECUTE 1 "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase0.sh   |& tee "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/phase0.log
  PHASE0_ENDTIME=$(date +%s)
fi

PHASE1_STARTTIME=$(date +%s)
echolog "Starting phase1 (logged in phase1.log )..."
NAMESPACE_EXECUTE 1 "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase1.sh     |& tee "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/phase1.log
PHASE1_ENDTIME=$(date +%s)

PHASE2_STARTTIME=$(date +%s)
echolog "Starting phase2 (logged in phase2.log )..."
NAMESPACE_EXECUTE 0 "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase2.sh     |& tee "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/phase2.log
PHASE2_ENDTIME=$(date +%s)
PHASE3_STARTTIME=$(date +%s)
echolog "Starting phase3 (logged in phase3.log )..."
NAMESPACE_EXECUTE 0 "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase3.sh     |& tee "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/phase3.log
PHASE3_ENDTIME=$(date +%s)

#Main Build Complete, Extract ISO and logs


#If the live cd did not build then tell user  
echolog "Moving built ISO files..."

EXPORT_STARTTIME=$(date +%s)
#Take a snapshot of the source

rm "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_Source_"$BUILDARCH".tar.gz
tar -czvf "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_Source_"$BUILDARCH".tar.gz -C "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/ . &>/dev/null


if [[ ! -f "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom-full.iso ]]
then  
  ISOFAILED=1
else
    mv "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom-full.iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_DevDbg_"$BUILDARCH".iso
fi 
if [[ ! -f "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom.iso ]]
then  
  ISOFAILED=1
else
    mv "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom.iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_"$BUILDARCH".iso
fi 

#Before the rest of the files are cleaned, export the logs, that are now also generated by the cleanup of the build source.
#Create a date string for unique log folder names
ENDDATE=$(date +"%Y-%m-%d_%H-%M-%S")

#Create a folder for the log files with the date string
mkdir -p ""$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH""

#Export the log files to the location
cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/* ""$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH""
rm ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""
ln -s ""$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH"" ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""
cp -a ""$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/usr/share/buildcore_revisions.txt" ""$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH"" 
cp -a ""$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/usr/share/buildcore_revisions.txt" ""$HOMELOCATION"/"$BUILDFRIENDLYNAME"_Revisions_"$BUILDARCH".txt"

#allow the user to actually read the iso   
chown $SUDO_USER "$HOMELOCATION"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".tar.gz
chgrp $SUDO_USER "$HOMELOCATION"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".tar.gz
chmod 777 "$HOMELOCATION"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".tar.gz

EXPORT_ENDTIME=$(date +%s)


echolog "Cleaning up non reusable build data..."  
POSTCLEANUP_STARTTIME=$(date +%s)
#Clean up.
if [[ $HASOVERLAYFS == 0 ]]
then
  NAMESPACE_EXECUTE 0 "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/cleanup_srcbuild.sh
fi

#Unmount the ramdisks, and bind mounts
if [[ $RAMDISK_FOR_BASE == 1 && $RAMDISK_STATUS == 0 ]]
then
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource
fi
if [[ $RAMDISK_FOR_PHASE3 == 1 && $RAMDISK_STATUS == 0 ]]
then
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3
fi
if [[ $RAMDISK_FOR_REMASTERSYS == 1 && $RAMDISK_STATUS == 0 ]]
then
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
fi
umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk


#Continue cleaning non reusable files
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/sourcehome/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/config/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay/*

rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile

POSTCLEANUP_ENDTIME=$(date +%s)
#If the live cd did  build then tell user   
if [[ $ISOFAILED != 1  ]];
then  
  echolog "Live CD image build was successful."
else
  echolog "The Live CD did not succesfuly build. The script could have been modified, or a network connection could have failed to one of the servers preventing the installation packages for Debian, or Remstersys from installing. There could also be a problem with the selected architecture for the build, such as an incompatible kernel or CPU, or a misconfigured qemu-system bin_fmt"
fi

ENDTIME=$(date +%s)

#Summarize cleanup time
echolog "build of $BUILDARCH finished in $((ENDTIME-STARTTIME)) seconds $REBUILT"

echolog -n "Prepare run time: $((PREPARE_ENDTIME-PREPARE_STARTTIME)) seconds, "
if [[ $RUN_PHASE_0 == 1 ]]
then
  echolog -n "Phase 0 build time: $((PHASE0_ENDTIME-PHASE0_STARTTIME)) seconds, " 
fi
echolog -n "Phase 1 build time: $((PHASE1_ENDTIME-PHASE1_STARTTIME)) seconds, "
echolog -n "Phase 2 build time: $((PHASE2_ENDTIME-PHASE2_STARTTIME)) seconds, "
echolog -n "Phase 3 build time: $((PHASE3_ENDTIME-PHASE3_STARTTIME)) seconds, "
echolog -n "Export time: $((EXPORT_ENDTIME-EXPORT_STARTTIME)) seconds, " 
echolog    "Cleanup time: $((POSTCLEANUP_ENDTIME-POSTCLEANUP_STARTTIME)) seconds" 



if [[ -e ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/package_operations/Downloads/failedpackages.log ]]
then
 echolog -e "\nPackages that failed to download:"
 LIST=$(cat ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/package_operations/Downloads/failedpackages.log | tr '\n' '|' | sed 's/|/. /g')
 echolog "$LIST"
 echolog " "
fi

if [[ -e ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/package_operations/Installs/failedpackages.log ]]
then
  echolog -e "\nPackages that failed to install:"
  LIST=$(cat ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/package_operations/Installs/failedpackages.log | tr '\n' '|' | sed 's/|/. /g')
  echolog "$LIST"
  echolog " "
fi

if [[ -e ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/build_core/failedcompiles ]]
then
  echolog -e "\nPackages that failed to compile:"
  LIST=$(cat ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/build_core/failedcompiles | tr '\n' ' ')
  echolog "$LIST"
  echolog " "
fi

#Write specially logged messages to te mainlog
echo "$LOGTEXT" > ""$BUILDLOCATION"/logs/latest-"$BUILDARCH""/mainlog.log

exit
}

#Start the build process
if [[ $BUILDER_IS_UNSHARED != 1 ]]
then
  export BUILDER_IS_UNSHARED=1
  tty -s
  TTYRESULT=$?
  if [[ $TTYRESULT == 0 ]]
  then
    exec sudo -E unshare --mount "$0" "$@"
  else
    if [[ $UID != 0 ]]
    then
      echo "Needs to be run as root outside of a terminal."
    else
      sudo -E python -c 'import pty, sys; pty.spawn(sys.argv[1:])' unshare --mount "$0" "$@"
    fi
  fi
else
  setup_buildprocess
  run_buildprocess "$@"
fi
