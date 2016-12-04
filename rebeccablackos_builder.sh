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

function setup_buildprocess
{
  #unset most varaibles
  while read var
  do 
    unset "$var"
  done < <(env | awk -F = '{print $1}' | grep -Ev "^PATH$|^HOME$|^SUDO_USER$" ) 
  export TERM=linux
  PATH=$(getconf PATH):/sbin:/usr/sbin
  export LANG=en_US.UTF-8
  HOMELOCATION=$HOME

  #If user presses CTRL+C, kill any namespace, remove the lock file, exit the script
  trap 'kill -9 $ROOTPID; rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile; exit' 2
}

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

#Declare most of the script as a function, to protect against the script from any changes when running, from causing the build process to be inconsistant
function run_buildprocess {

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
  echo "Error: Another instance is already running for $BUILDARCH"
  exit
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

     "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt 

with the requested revisions file generated from a previous build, or a downloaded instance. 


You may also specify a list of pacakges in

     "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt 

to batch restart, one package per line.


Although the files have the CPU architecture as the suffix in the file name, there is nothing CPU dependant in them, and the suffix only exists to identify them. 
For example buildcore_revisions_amd64.txt can be used in "$BUILDLOCATION"/buildcore_revisions_i386.txt 
and
RestartPackageList_amd64.txt can be used in RestartPackageList_i386.txt

Ensure the file(s) are copied, and not moved, as they are treated as a one time control file, and deleted after the next run."


if [[ $SKIPPROMPT != 1 ]]
then
  echo "Most users can ignore this message. Press Enter to continue..."
  read wait
else
  echo "Most users can ignore this message. The build process will start in 5 seconds"
  sleep 5
fi
STARTTIME=$(date +%s)
PREPARE_STARTTIME=$(date +%s)

#prepare debootstrap
if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap || ! -e "$BUILDLOCATION"/DontDownloadDebootstrapScript ]]
then
  echo "Control file for debootstrap removed, or non existing. Deleting downloaded debootstrap folder"
  touch "$BUILDLOCATION"/DontDownloadDebootstrapScript
  rm -rf "$BUILDLOCATION"/debootstrap/*
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

echo "Starting the build process..."

REBUILT="to update"

#Delete buildoutput based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH" ]]
then
  echo "Control file for buildoutput removed, or non existing. Deleting compiled .deb files for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput/*
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput
  touch "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH"
fi

#Delete archives based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH" ]]
then
  echo "Control file for archives removed, or non existing. Deleting downloaded cached .deb files for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives/*
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/archives
  touch "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH"
fi

#Delete downloaded source based on a control file
if [[ ! -f "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH" ]]
then
  echo "Control file for srcbuild removed, or non existing. Deleting downloaded sources for $BUILDARCH"
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/*
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild
  touch "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH"
fi

#Only run phase0 if phase1 and phase2 are going to be reset. phase0 only resets
RUN_PHASE_0=0
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
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/workdir/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildoutput/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/archives/*
    rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/*
    rm "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
    rm "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
    touch "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH"
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.installbak
    REBUILT="to rebuild from scratch"
  fi
  RUN_PHASE_0=1
fi

#Delete any stale files
echo "Cleaning up any stale remaining files from any incomplete build..."
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay/*


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
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/unionwork
mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk

#Determine the size of the ram disk, 3GB free, give 1GB for storing logs and base
FREERAM=$(grep MemAvailable: /proc/meminfo | awk '{print $2}')
if [[ $FREERAM -gt 3000000 ]]
then
  RAMDISK_FOR_BASE=1
  RAMDISKSIZE=1000000
fi
#4G free, give 1GB more for srcbuild overlay. (emptied after each build)
if [[ $FREERAM -gt 5000000 ]]
then
  RAMDISK_FOR_SRCBUILD=1
  RAMDISKSIZE=2000000
fi
#8GB free, give 4GB more for phase_3 overlay
if [[ $FREERAM -gt 8000000 ]]
then
  RAMDISK_FOR_PHASE3=1
  RAMDISKSIZE=6000000
fi
#14GB free, give 6GB more for phase_3 overlay
if [[ $FREERAM -gt 14000000 ]]
then
  RAMDISK_FOR_REMASTERSYS=1
  RAMDISKSIZE=16000000
fi

#Mount the ramdisk
mount -t tmpfs -o size=${RAMDISKSIZE}k tmpfs "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk
RAMDISK_STATUS=$?

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
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork
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
rsync "$SCRIPTFOLDERPATH"/rebeccablackos_files/* -Cr "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
rsync "$SCRIPTFOLDERPATH"/* -Cr "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource

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
    echo "       Marked package: $RESETPACKAGE for rebuild."
  fi
done
echo -n > "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt

#make the imported files executable 
chmod 0755 -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
chown  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
chgrp  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/

PREPARE_ENDTIME=$(date +%s)

#run the build scripts
if [[ $RUN_PHASE_0 == 1 ]]
then
  PHASE0_STARTTIME=$(date +%s)
  NAMESPACE_EXECUTE "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/rebeccablackos_phase0.sh
  PHASE0_ENDTIME=$(date +%s)
fi

PHASE1_STARTTIME=$(date +%s)
NAMESPACE_EXECUTE "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/rebeccablackos_phase1.sh
PHASE1_ENDTIME=$(date +%s)

PHASE2_STARTTIME=$(date +%s)
NAMESPACE_EXECUTE "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/rebeccablackos_phase2.sh
PHASE2_ENDTIME=$(date +%s)

PHASE3_STARTTIME=$(date +%s)
NAMESPACE_EXECUTE "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/rebeccablackos_phase3.sh 
PHASE3_ENDTIME=$(date +%s)

#Main Build Complete, Extract ISO and logs


#Take a snapshot of the source
rm "$HOMELOCATION"/RebeccaBlackOS_Source_"$BUILDARCH".tar.gz
tar -czvf "$HOMELOCATION"/RebeccaBlackOS_Source_"$BUILDARCH".tar.gz -C "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/ . &>/dev/null


#If the live cd did not build then tell user  
if [[ ! -f "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom-full.iso ]]
then  
  ISOFAILED=1
else
    mv "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom-full.iso "$HOMELOCATION"/RebeccaBlackOS_DevDbg_"$BUILDARCH".iso
fi 
if [[ ! -f "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom.iso ]]
then  
  ISOFAILED=1
else
    mv "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/remastersys/custom.iso "$HOMELOCATION"/RebeccaBlackOS_"$BUILDARCH".iso
fi 


#allow the user to actually read the iso   
chown $SUDO_USER "$HOMELOCATION"/RebeccaBlackOS*.iso "$HOMELOCATION"/RebeccaBlackOS_*.txt "$HOMELOCATION"/RebeccaBlackOS_*.tar.gz
chgrp $SUDO_USER "$HOMELOCATION"/RebeccaBlackOS*.iso "$HOMELOCATION"/RebeccaBlackOS_*.txt "$HOMELOCATION"/RebeccaBlackOS_*.tar.gz
chmod 777 "$HOMELOCATION"/RebeccaBlackOS*.iso "$HOMELOCATION"/RebeccaBlackOS_*.txt "$HOMELOCATION"/RebeccaBlackOS_*.tar.gz


echo "Cleaning up non reusable build data..."  

#Clean up.
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/vartmp/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/*
POSTCLEANUP_STARTTIME=$(date +%s)
NAMESPACE_EXECUTE "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/cleanup_srcbuild.sh
POSTCLEANUP_ENDTIME=$(date +%s)

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
cp -a ""$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/usr/share/buildcore_revisions.txt" ""$HOMELOCATION"/RebeccaBlackOS_Revisions_"$BUILDARCH".txt"

#Continue cleaning non reusable files
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/*
rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild_overlay/*

rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile 

#If the live cd did  build then tell user   
if [[ $ISOFAILED != 1  ]];
then  
  echo "Live CD image build was successful."
else
  echo "The Live CD did not succesfuly build. The script could have been modified, or a network connection could have failed to one of the servers preventing the installation packages for Debian, or Remstersys from installing. There could also be a problem with the selected architecture for the build, such as an incompatible kernel or CPU, or a misconfigured qemu-system bin_fmt"
fi

ENDTIME=$(date +%s)

#Summarize cleanup time
echo "build of $BUILDARCH finished in $((ENDTIME-STARTTIME)) seconds $REBUILT"

echo -n "Prepare run time: $((PREPARE_ENDTIME-PREPARE_STARTTIME)) seconds, "
if [[ $RUN_PHASE_0 == 1 ]]
then
  echo -n "Phase 0 build time: $((PHASE0_ENDTIME-PHASE0_STARTTIME)) seconds, " 
fi
echo -n "Phase 1 build time: $((PHASE1_ENDTIME-PHASE1_STARTTIME)) seconds, "
echo -n "Phase 2 build time: $((PHASE2_ENDTIME-PHASE2_STARTTIME)) seconds, "
echo -n "Phase 3 build time: $((PHASE3_ENDTIME-PHASE3_STARTTIME)) seconds, "
echo    "Post Cleanup time: $((POSTCLEANUP_ENDTIME-POSTCLEANUP_STARTTIME)) seconds" 


exit
}

#Start the build process
if [[ $BUILDER_IS_UNSHARED != 1 ]]
then
  export BUILDER_IS_UNSHARED=1
  sudo -E unshare -f --mount "$0" "$@"
else
  setup_buildprocess
  run_buildprocess
fi
