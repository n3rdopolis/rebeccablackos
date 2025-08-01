#! /bin/bash
#    Copyright (c) 2012 - 2025 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

shopt -s dotglob

#This function retrives the PID, and some of the child PIDs, to eventually get the pid 1 of the namespace for the build
function GetJobPIDs
{
  if [[ -d /proc/$SUBSHELLPID ]]
  then
    PYTHONPID=$(pgrep -oP $SUBSHELLPID 2>/dev/null)
  else
    ROOTPID=-1
    return
  fi

  if [[ -d /proc/$PYTHONPID ]]
  then
    UNSHAREPID=$(pgrep -oP $PYTHONPID 2>/dev/null)
  else
    ROOTPID=-1
    return
  fi

  if [[ -d /proc/$UNSHAREPID ]]
  then
    ROOTPID=$(pgrep -oP $UNSHAREPID 2>/dev/null)
  else
    ROOTPID=-1
  fi
}

#This function takes the same arguments as echo, behaves like echo, except all the text is saved in a variable to be written to a log later
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

#This function takes the same arguments as echo, like echolog, but then writes to a failure log, and exits the script
#THis is for when the script itself cannot initailize phase0, 1, 2, or 3, not for when an ISO fails to build
function faillog
{
  echolog "$@"

  echo "$LOGTEXT" > "$BUILDLOCATION"/logs/failedlogs/Failed_"$STARTDATE"_"$BUILDARCH".log
  rm "$BUILDLOCATION"/logs/failedlogs/latest-failedlog_"$BUILDARCH".log 2>/dev/null
  ln -s "$BUILDLOCATION"/logs/failedlogs/Failed_"$STARTDATE"_"$BUILDARCH".log "$BUILDLOCATION"/logs/failedlogs/latest-failedlog_"$BUILDARCH".log
  exit 1
}

function setup_buildprocess
{
  #unset most varaibles
  unset VARLIST
  CALLING_SUDO_USER=$SUDO_USER
  HOMELOCATION=$HOME
  OLDBUILDROOT=$HOME

  PATH=$(getconf PATH):/sbin:/usr/sbin
  VARLIST=$(env | awk -F = '{print $1}' | grep -Ev "^PATH$" )
  for var in $VARLIST
  do 
    unset "$var" &> /dev/null
  done

  #Detect the best Python command to use
  PYTHONTESTCOMMANDS=(python3 python2 python2.7 python)
  for PYTHONTESTCOMMAND in "${PYTHONTESTCOMMANDS[@]}"
  do
    type $PYTHONTESTCOMMAND &> /dev/null
    if [[ $? == 0 ]]
    then
      export PYTHONCOMMAND=$PYTHONTESTCOMMAND
      break
    fi
  done

  export TERM=linux
  export LANG=C.UTF-8
  STARTDATE=$(date +"%Y-%m-%d_%H-%M-%S")

  if [[ ! -z $CALLING_SUDO_USER ]]
  then
    WGETCOMMAND="runuser -u ${CALLING_SUDO_USER} -- wget"
  else
    WGETCOMMAND="wget"
  fi

  #If user presses CTRL+C, kill any namespace, remove the lock file, exit the script
  trap 'if [[ $BUILD_RUNNING == 0 ]];
          then exit 2;
        fi;

        if [[ -z $ROOTPID ]];
          then GetJobPIDs;
        fi;

        if [[ -e /proc/"$ROOTPID" && $ROOTPID != "" && $ROOTPID != -1 ]];
          then kill -9 $ROOTPID;
          rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile;
          echo -e "\nCTRL+C pressed, exiting...";
          exit 2;
        fi' SIGINT

  #Handle when the script is resumed
  trap 'if [[ -e /proc/"$SUBSHELLPID" && $SUBSHELLPID != "" ]];
          then kill -CONT $SUBSHELLPID;
        fi;

        if [[ -e /proc/"$ROOTPID" && $ROOTPID != "" && $ROOTPID != -1 ]];
          then pkill -CONT --nslist pid --ns $ROOTPID "";
        fi' SIGCONT

  #Stop the background process that the script is waiting on when CTRL+Z is sent
  trap 'echo "CTRL+Z pressed, pausing...";
        if [[ -z $ROOTPID ]];
          then GetJobPIDs;
        fi;

        if [[ -e /proc/"$ROOTPID" && $ROOTPID != "" && $ROOTPID != -1 ]];
          then pkill -STOP --nslist pid --ns $ROOTPID "";
        fi

        if [[ -e /proc/"$SUBSHELLPID" && $SUBSHELLPID != "" && $ROOTPID != "" && $ROOTPID != -1 ]];
          then kill -STOP $SUBSHELLPID;
        fi;

        if [[ $ROOTPID != "" && $ROOTPID != -1 ]]
        then
          kill -STOP $$
        fi' SIGTSTP
}

#Function to start a command and all arguments, starting from the third one, as a command in a seperate PID and mount namespace. The first argument determines if the namespace should have network connectivity or not (1 = have network connectivity, 0 = no network connectivity). The second argument states where the log output will be written.
function NAMESPACE_EXECUTE {
  HASNETWORK=$1
  shift
  LOGFILE="$1"
  echolog "   Logging to $(basename $LOGFILE)"
  shift

  if [[ $HASNETWORK == 0 ]]
  then
    UNSHAREFLAGS="-f --cgroup --ipc --uts --pid --mount --net --mount-proc"
  else
    UNSHAREFLAGS="-f --cgroup --ipc --uts --pid --mount --mount-proc"
  fi

  #Create the PID and Mount namespaces to start the command in
  ($PYTHONCOMMAND -c 'import pty, sys; from signal import signal, SIGPIPE, SIG_DFL; signal(SIGPIPE,SIG_DFL); pty.spawn(sys.argv[1:])' bash -c "stty cols 80 rows 24; exec unshare $UNSHAREFLAGS "$@"" |& tee "$LOGFILE" ) &
  SUBSHELLPID=$!

  #Get the PID of the unshared process, which is pid 1 for the namespace, wait at the very most 1 minute for the process to start, 120 attempts with half 1 second intervals.
  #Abort if not started in 1 minute
  for (( element = 0 ; element < 120 ; element++ ))
  do
    read -t .5
    GetJobPIDs
    if [[ ! -z $ROOTPID ]]
    then
      break
    fi
  done
  if [[ -z $ROOTPID ]]
  then
    faillog "The main namespace process failed to start, in 1 minute. This should not take that long"
  fi


  #Wait for the PID to complete
  if [[ $ROOTPID != -1 ]]
  then
    read -r < <(tail -f /dev/null --pid=$UNSHAREPID)
  fi
  unset SUBSHELLPID
  unset PYTHONPID
  unset UNSHAREPID
  unset ROOTPID
}

#Declare most of the script as a function, to protect against the script from any changes when running, from causing the build process to be inconsistant
function run_buildprocess {
  type dpkg &> /dev/null
  if [[ $? != 0 ]]
  then
    DEFAULT_ARCH=amd64
  else
    DEFAULT_ARCH=$(dpkg --print-architecture)
  fi

  EXITSTATUS=0
  BUILD_RUNNING=0

  SCRIPTFILEPATH=$(readlink -f "$0")
  SCRIPTFOLDERPATH=$(dirname "$SCRIPTFILEPATH")

  define_config

  #Move to /var/cache if an existing build folder exists. With systemd-homed and the problems caused by UIDs moved in a migrated home directory, it's best to store in /var/cache
  if [[ -d "$OLDBUILDROOT"/$BUILDFOLDERNAME && ! -d "$BUILDROOT"/$BUILDFOLDERNAME ]]
  then
    echolog "Moving $OLDBUILDROOT/$BUILDFOLDERNAME to $BUILDROOT/$BUILDFOLDERNAME"
    mv "$OLDBUILDROOT"/$BUILDFOLDERNAME "$BUILDROOT"/$BUILDFOLDERNAME
  fi

  export BUILDLOCATION="$BUILDROOT"/$BUILDFOLDERNAME

  #make a folder containing the live cd tools in the users local folder
  mkdir -p "$BUILDLOCATION"

  #Create the logs folder for any logs the script may need to write if it aborts early
  mkdir -p "$BUILDLOCATION"/logs/failedlogs

  #Create the output directory
  mkdir -p "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/
  chown $CALLING_SUDO_USER "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/
  chgrp $CALLING_SUDO_USER "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/

  echolog "Build script for $BUILDFRIENDLYNAME. The build process requires no user interaction, apart from specifing the build architecture, and sending a keystroke to confirm to starting the build process.
  "

  export BUILDARCH=$(echo $1| grep BUILDARCH | awk -F = '{print $2}')
  export REVISIONSFILE=$2
  DONODELAY=0
  if [[ -z "$BUILDARCH" ]]
  then
    echolog "Select architecture:"
    echolog "  Enter 0 or press Enter to build an ISO matching the current architecture ($DEFAULT_ARCH)"
    echolog "  Enter 1 for amd64"
    echolog "  Enter 2 for i386 (Unsupported)"
    echolog "  Enter 3 for arm64 (Unsupported)"
    echolog "  Enter 4 for armhf (Unsupported)"
    echolog "  Enter 5 for a prompt for a custom architecture (Unsupported)"
    echolog "The arch can also be selected by passing BUILDARCH=(architecture) as the first argument. The second argument can be a path to a handled revisions file."
    read -r archselect
    if [[ $archselect == 0 ]]
    then
      export BUILDARCH=$DEFAULT_ARCH
    elif [[ $archselect == 1 ]]
    then
      export BUILDARCH=amd64
    elif [[ $archselect == 2 ]]
    then
      export BUILDARCH=i386
    elif [[ $archselect == 3 ]]
    then
      export BUILDARCH=arm64
    elif [[ $archselect == 4 ]]
    then
      export BUILDARCH=armhf
    elif [[ $archselect == 5 ]]
    then
      echolog "Enter custom CPU arch. Please ensure your processor is capable of running the selected architecture."
      read -r BUILDARCH
      export BUILDARCH=$BUILDARCH
    else
      export BUILDARCH=$DEFAULT_ARCH
    fi
    SHOWSKIPPROMPT=0
  else
    SHOWSKIPPROMPT=1
  fi
  if [[ ! -z "$REVISIONSFILE" ]]
  then
    DONODELAY=1
  fi

  #Checkinstall needs overlayfs
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

  #Detect another instance, by creating a testing a lockfile, which is a symlink to /proc/pid/cmdline, and making sure the second line of /proc/pid/cmdline matches (as it's the path to the script).
  ls "$(readlink -f "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile)" &> /dev/null
  result=$?
  if [[ $result != 0 || ! -e "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile  ]]
  then
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"
    rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile &> /dev/null
    "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile 2>/dev/null
    ln -s /proc/"$$"/cmdline "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile
  else
    LockPID=$(readlink -f "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile | awk -F "/" '{print $3}')
    faillog "Error: Another instance is already running for $BUILDARCH (pid $LockPID)"
  fi

  #Copy in a revisions file if specified
  if [[ ! -z "$REVISIONSFILE" ]]
  then
    cp "$REVISIONSFILE" "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt
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
    
   Folder:            $BUILDLOCATION/
   Folder:            ${HOMELOCATION}/${BUILDFRIENDLYNAME}/
   File:              ${HOMELOCATION}/${BUILDFRIENDLYNAME}/${BUILDFRIENDLYNAME}_${BUILDARCH}.iso
   File:              ${HOMELOCATION}/${BUILDFRIENDLYNAME}/${BUILDFRIENDLYNAME}_DevDbg_${BUILDARCH}.iso
   File:              ${HOMELOCATION}/${BUILDFRIENDLYNAME}/${BUILDFRIENDLYNAME}_Revisions_${BUILDARCH}.txt
   File:              ${HOMELOCATION}/${BUILDFRIENDLYNAME}/${BUILDFRIENDLYNAME}_Source_${BUILDARCH}.tar.gz
"

  echolog "----------------------------------------------------------------------------------------

If you want to build revisions specified in a list file from a previous build, overwrite 

     $BUILDLOCATION/buildcore_revisions_$BUILDARCH.txt 

with the requested revisions file generated from a previous build, or a downloaded instance, or specify it as the second argument after BUILDARCH=(architecture)
to have it copied in.

You may also specify a list of pacakges in

     $BUILDLOCATION/RestartPackageList_$BUILDARCH.txt 

to batch restart, one package per line.


Although the files have the CPU architecture as the suffix in the file name, there is nothing CPU dependant in them, and the suffix only exists to identify them. 
For example buildcore_revisions_amd64.txt can be used in $BUILDLOCATION/buildcore_revisions_i386.txt 
and
RestartPackageList_amd64.txt can be used in RestartPackageList_i386.txt

Ensure the file(s) are copied, and not moved, as they are treated as a one time control file, and deleted after the next run.
-----------------------------------------------------------------------------------------------------------------------------"

  if [[ $DONODELAY != 1 ]]
  then
    if [[ $SHOWSKIPPROMPT != 1 ]]
    then
      echolog "Most users can ignore this message. Press Enter to continue..."
      read wait
    else
      echolog "Most users can ignore this message. The build process will start in 5 seconds"
      sleep 5
    fi
  fi
  STARTTIME=$(date +%s)
  PREPARE_STARTTIME=$(date +%s)

  #prepare debootstrap
  if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap || ! -e "$BUILDLOCATION"/debootstrap/keyrings/debian-archive-keyring.gpg || ! -e "$BUILDLOCATION"/DontDownloadDebootstrapScript ]]
  then
    type ar &> /dev/null
    if [[ $? != 0 ]]
    then
      faillog "ar command not installed. ar is needed to extract debootstrap, and usually comes with binutils"
    fi

    echolog "Control file for debootstrap removed, or non existing. Deleting downloaded debootstrap folder"
    touch "$BUILDLOCATION"/DontDownloadDebootstrapScript
    mkdir -p "$BUILDLOCATION"/debootstrap
    rm -rf "$BUILDLOCATION"/debootstrap/*
    mkdir -p "$BUILDLOCATION"/debootstrap/keyrings
    DEBURLS=$($WGETCOMMAND -O - https://httpredir.debian.org/debian/indices/files/components/suite-unstable.list.gz 2>/dev/null | gzip -d | grep '\.deb$' |grep -E /debootstrap/\|/debian-archive-keyring/)
    DEBOOTSTRAPURL=$(echo "$DEBURLS" | grep /debootstrap/ | sed 's/^.//g')
    ARCHIVEKEYURL=$(echo "$DEBURLS" | grep /debian-archive-keyring/ | sed 's/^.//g')

    $WGETCOMMAND -O - https://httpredir.debian.org/debian/$DEBOOTSTRAPURL 2>/dev/null > "$BUILDLOCATION"/debootstrap/debootstrap.deb
    $WGETCOMMAND -O - https://httpredir.debian.org/debian/$ARCHIVEKEYURL 2>/dev/null > "$BUILDLOCATION"/debootstrap/debian-archive-keyring.deb

    TARNAME=$(ar t "$BUILDLOCATION"/debootstrap/debootstrap.deb |grep 'data\.tar\.')
    ar p "$BUILDLOCATION"/debootstrap/debootstrap.deb $TARNAME > "$BUILDLOCATION"/debootstrap/debootstrap.tar
  
    TARNAME=$(ar t "$BUILDLOCATION"/debootstrap/debian-archive-keyring.deb |grep 'data\.tar\.')
    ar p "$BUILDLOCATION"/debootstrap/debian-archive-keyring.deb $TARNAME > "$BUILDLOCATION"/debootstrap/debian-archive-keyring.tar

    DEBOOTSTRIPBINPATH=$(tar -atf "$BUILDLOCATION"/debootstrap/debootstrap.tar | grep bin/debootstrap$)
    tar -axf "$BUILDLOCATION"/debootstrap/debootstrap.tar --strip-components=3 -C "$BUILDLOCATION"/debootstrap "$DEBOOTSTRIPBINPATH"
    tar -axf "$BUILDLOCATION"/debootstrap/debootstrap.tar --strip-components=4 -C "$BUILDLOCATION"/debootstrap ./usr/share/debootstrap/scripts
    tar -axf "$BUILDLOCATION"/debootstrap/debootstrap.tar --strip-components=4 -C "$BUILDLOCATION"/debootstrap ./usr/share/debootstrap/functions
    tar -axf "$BUILDLOCATION"/debootstrap/debian-archive-keyring.tar --strip-components=4 -C "$BUILDLOCATION"/debootstrap/keyrings ./usr/share/keyrings/debian-archive-keyring.gpg

    if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap || ! -e "$BUILDLOCATION"/debootstrap/scripts || ! -e "$BUILDLOCATION"/debootstrap/functions || ! -e "$BUILDLOCATION"/debootstrap/keyrings/debian-archive-keyring.gpg ]]
    then
      faillog "failed to bootstrap debootstrap"
    fi
  fi

  #If debootstrap fails
  if [[ ! -e "$BUILDLOCATION"/debootstrap/debootstrap ]]
  then 
    faillog "Download of debootstrap failed, this script needs to be able to download debootstrap from ftp.debian.org in order to be able to continue."
  fi

  #Determine how much free disk space is neeed
  ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PADDING))

  #Determine how much space is in use by the ISOs already, and take that value away from the space allocated towards the output ISO, and append it
  CURRENT_ISOOUT=$(du -c "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso 2>/dev/null | tail -1 | awk '{print $1}')
  ((STORAGESIZE_TOTALSIZE_OUTPUT=(STORAGESIZE_ISOOUT-CURRENT_ISOOUT)))

  #ISOs will be built in the build location, and moved out into the destination directory. Account for the temporary space used
  ((STORAGESIZE_TOTALSIZE+=(STORAGESIZE_ISOOUT-CURRENT_ISOOUT)))

  echolog "Starting the build process..."

  REBUILT="to update"

  #Move the builder in its own cgroup, systemd managed user sessions start applications like terminal emulators in their own cgroup. This avoids making the oom killer kill the whole terminal emulator if the system is low on RAM
  OriginalCgroup=$(cat /proc/self/cgroup | sed 's|^0::|/sys/fs/cgroup|g')
  mkdir -p /sys/fs/cgroup/machine.slice/"$BUILDUNIXNAME"_builder:"$BUILDARCH"
  echo $$ > /sys/fs/cgroup/machine.slice/"$BUILDUNIXNAME"_builder:"$BUILDARCH"/cgroup.procs

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

  if [[ ! -f "$BUILDLOCATION"/DontForceSnapshotBuild"$BUILDARCH" && -f "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH" ]]
  then
    FORCE_SNAPSHOT_BUILD=1
    touch "$BUILDLOCATION"/DontForceSnapshotBuild"$BUILDARCH"
  else
    FORCE_SNAPSHOT_BUILD=0
  fi

  if [[ -s "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt || $FORCE_SNAPSHOT_BUILD == 1 ]]
  then
    if [[ -s "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt ]]
    then
      APTFETCHDATESECONDS=$(grep APTFETCHDATESECONDS= "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt | head -1 | sed 's/APTFETCHDATESECONDS=//g')
    fi

    export PHASE1_PATHNAME=snapshot_phase_1
    export PHASE2_PATHNAME=snapshot_phase_2
    export BUILD_SNAPSHOT_SYSTEMS=1
    RUN_PHASE_0=1
    echolog "Clearing phase1 and phase2 snapshot build systems..."
    rm -rf  "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_1/*
    rm -rf  "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2/*
  else
    export PHASE1_PATHNAME=phase_1
    export PHASE2_PATHNAME=phase_2
    export BUILD_SNAPSHOT_SYSTEMS=0
  fi
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
      rm -rf  "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_1/*
      rm -rf  "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2/*
      rm "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH"
      rm "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH"
      rm "$BUILDLOCATION"/DontRestartBuildoutput"$BUILDARCH"
      rm "$BUILDLOCATION"/DontRestartArchives"$BUILDARCH"
      rm "$BUILDLOCATION"/DontRestartSourceDownload"$BUILDARCH"
      touch "$BUILDLOCATION"/DontStartFromScratch"$BUILDARCH"
      touch "$BUILDLOCATION"/DontForceSnapshotBuild"$BUILDARCH"
      mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
      touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.lastrun
      REBUILT="to rebuild from scratch"
    fi

    #if set to rebuild phase 1
    if [[ ! -f "$BUILDLOCATION"/DontRestartPhase1"$BUILDARCH" && $BUILD_SNAPSHOT_SYSTEMS == 0 ]]
    then
      echolog "Control file for phase_1 removed, or non existing. Deleting phase_1 system for $BUILDARCH"
      rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_1/*
      ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PHASE1))
    fi

    #if set to rebuild phase 2
    if [[ ! -f "$BUILDLOCATION"/DontRestartPhase2"$BUILDARCH" && $BUILD_SNAPSHOT_SYSTEMS == 0 ]]
    then
      echolog "Control file for phase_2 removed, or non existing. Deleting phase_2 system for $BUILDARCH"
      rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/*
      mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp
      touch "$BUILDLOCATION"/build/"$BUILDARCH"/phase_2/tmp/INSTALLS.txt.lastrun
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
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_1
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2
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

  RAMDISKED_TEMP_FOLDERS=0
  TOTAL_TEMP_FOLDERS=0
  FREERAM=$(grep MemAvailable: /proc/meminfo | awk '{print $2}')

  RAMDISKSIZE=$STORAGESIZE_PADDING
  #Determine the size of the ram disk, determine if enough free ram for base in ramdisk
  ((TOTAL_TEMP_FOLDERS++))
  RAMDISKTESTSIZE=$((RAMDISKSIZE+STORAGESIZE_TMPBASEBUILD))
  OPTIMAL_FREE_RAM=$((RAMDISKSIZE+STORAGESIZE_TMPBASEBUILD))
  if [[ $FREERAM -gt $RAMDISKTESTSIZE ]]
  then
    echolog "More than $(( ((RAMDISKTESTSIZE+1023) /1024 + 1023) /1024 ))GB of RAM Free. Using a ramdisk for base temporary folders."
    ((RAMDISKED_TEMP_FOLDERS++))
    RAMDISK_FOR_BASE=1
    RAMDISKSIZE=$RAMDISKTESTSIZE
  else
    echolog "Not enough free RAM to use a ramdisk for base temporary folders."
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPBASEBUILD))
    RAMDISKTESTSIZE=$RAMDISKSIZE
  fi

  #Determine if enough free RAM for srcbuild_overlay in ramdisk
  ((TOTAL_TEMP_FOLDERS++))
  RAMDISKTESTSIZE=$((RAMDISKTESTSIZE+STORAGESIZE_TMPSRCBUILDOVERLAY))
  OPTIMAL_FREE_RAM=$((OPTIMAL_FREE_RAM+STORAGESIZE_TMPSRCBUILDOVERLAY))
  if [[ $FREERAM -gt $RAMDISKTESTSIZE ]]
  then
    echolog "More than $(( ((RAMDISKTESTSIZE+1023) /1024 + 1023) /1024 ))GB of RAM Free. Using a ramdisk for srcbuild overlay"
    ((RAMDISKED_TEMP_FOLDERS++))
    RAMDISK_FOR_SRCBUILD=1
    RAMDISKSIZE=$RAMDISKTESTSIZE
  else
    echolog "Not enough free RAM to use a ramdisk for srcbuild overlay."
    RAMDISKTESTSIZE=$RAMDISKSIZE
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPSRCBUILDOVERLAY))
  fi

  #Determine if enough free RAM for phase3 in ramdisk
  ((TOTAL_TEMP_FOLDERS++))
  RAMDISKTESTSIZE=$((RAMDISKTESTSIZE+STORAGESIZE_TMPPHASE3))
  OPTIMAL_FREE_RAM=$((OPTIMAL_FREE_RAM+STORAGESIZE_TMPPHASE3))
  if [[ $FREERAM -gt $RAMDISKTESTSIZE ]]
  then
    echolog "More than $(( ((RAMDISKTESTSIZE+1023) /1024 + 1023) /1024 ))GB of RAM Free. Using a ramdisk for phase 3"
    ((RAMDISKED_TEMP_FOLDERS++))
    RAMDISK_FOR_PHASE3=1
    RAMDISKSIZE=$RAMDISKTESTSIZE
  else
    echolog "Not enough free RAM to use a ramdisk for phase 3."
    RAMDISKTESTSIZE=$RAMDISKSIZE
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPPHASE3))
  fi

  if [[ $BUILD_SNAPSHOT_SYSTEMS == 1 ]]
  then
    ((TOTAL_TEMP_FOLDERS++))
    RAMDISKTESTSIZE=$((RAMDISKSIZE+STORAGESIZE_PHASE1))
    OPTIMAL_FREE_RAM=$((OPTIMAL_FREE_RAM+STORAGESIZE_PHASE1))
    if [[ $FREERAM -gt $RAMDISKTESTSIZE ]]
    then
      echolog "More than $(( ((RAMDISKTESTSIZE+1023) /1024 + 1023) /1024 ))GB of RAM Free. Using a ramdisk for phase 1"
      ((RAMDISKED_TEMP_FOLDERS++))
      RAMDISK_FOR_PHASE1=1
      RAMDISKSIZE=$RAMDISKTESTSIZE
    else
      echolog "Not enough free RAM to use a ramdisk for phase 2."
      RAMDISKTESTSIZE=$RAMDISKSIZE
      ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PHASE1))
    fi

    ((TOTAL_TEMP_FOLDERS++))
    RAMDISKTESTSIZE=$((RAMDISKSIZE+STORAGESIZE_PHASE2-STORAGESIZE_PHASE1))
    OPTIMAL_FREE_RAM=$((OPTIMAL_FREE_RAM+STORAGESIZE_PHASE2-STORAGESIZE_PHASE1))
    if [[ $FREERAM -gt $RAMDISKTESTSIZE ]]
    then
      echolog "More than $(( ((RAMDISKTESTSIZE+1023) /1024 + 1023) /1024 ))GB of RAM Free. Using a ramdisk for phase 2"
      ((RAMDISKED_TEMP_FOLDERS++))
      RAMDISK_FOR_PHASE2=1
      RAMDISKSIZE=$RAMDISKTESTSIZE
    else
      echolog "Not enough free RAM to use a ramdisk for phase 2."
      RAMDISKTESTSIZE=$RAMDISKSIZE
      ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_PHASE2))
      #If this is snapshot, the phase 1 is temporary, and deleted once it completes all downloads, in favor of phase 2
      ((STORAGESIZE_TOTALSIZE-=STORAGESIZE_PHASE1))
    fi

  fi

  #Determine if enough free RAM for Remastersys in ramdisk
  ((TOTAL_TEMP_FOLDERS++))
  RAMDISKTESTSIZE=$((RAMDISKSIZE+STORAGESIZE_TMPREMASTERSYS))
  OPTIMAL_FREE_RAM=$((OPTIMAL_FREE_RAM+STORAGESIZE_TMPREMASTERSYS))
  if [[ $FREERAM -gt $RAMDISKTESTSIZE ]]
  then
    echolog "More than $(( ((RAMDISKTESTSIZE+1023) /1024 + 1023) /1024 ))GB of RAM Free. Using a ramdisk for remastersys"
    ((RAMDISKED_TEMP_FOLDERS++))
    RAMDISK_FOR_REMASTERSYS=1
    RAMDISKSIZE=$RAMDISKTESTSIZE
  else
    echolog "Not enough free RAM to use a ramdisk for remastersys."
    RAMDISKTESTSIZE=$RAMDISKSIZE
    ((STORAGESIZE_TOTALSIZE+=STORAGESIZE_TMPREMASTERSYS))
  fi

  #get the size of the output location
  FREEDISKSPACE_OUTPUT=$(df --output=avail $HOMELOCATION | tail -1)
  #if there is less than the required amount of space, then exit.
  if [[ $FREEDISKSPACE_OUTPUT -le $STORAGESIZE_TOTALSIZE_OUTPUT ]]
  then
    echolog "You have less then $(( ((STORAGESIZE_TOTALSIZE_OUTPUT+1023) /1024 + 1023) /1024 ))GB of free space on the filesystem $(df --output=target $HOMELOCATION | tail -1) for $HOMELOCATION. Please free up some space."
    echolog "The script will now abort."
    faillog "free space: $FREEDISKSPACE_OUTPUT"
  else
    echolog -e "\n\nFree disk space needed for ISO output: $(( ((STORAGESIZE_TOTALSIZE_OUTPUT+1023) /1024 + 1023) /1024 ))GB, Current free disk space for ISO output: $(( ((FREEDISKSPACE_OUTPUT+1023) /1024 + 1023) /1024 ))GB"
  fi

  #get the size of the build location
  FREEDISKSPACE_BUILDSPACE=$(df --output=avail $BUILDLOCATION | tail -1)
  #if there is less than the required amount of space, then exit.
  if [[ $FREEDISKSPACE_BUILDSPACE -le $STORAGESIZE_TOTALSIZE ]]
  then
    echolog "You have less then $(( ((STORAGESIZE_TOTALSIZE+1023) /1024 + 1023) /1024 ))GB of free space on the filesystem $(df --output=target $BUILDLOCATION | tail -1) for $BUILDLOCATION. Please free up some space."
    echolog "The script will now abort."
    faillog "free space: $FREEDISKSPACE_BUILDSPACE"
  else
    echolog -e "Current free RAM: $(( ((FREERAM+1023) /1024 + 1023) /1024 ))GB; RAM disk maximum size: $(( ((RAMDISKSIZE+1023) /1024 + 1023) /1024 ))GB, Free disk space needed for build: $(( ((STORAGESIZE_TOTALSIZE+1023) /1024 + 1023) /1024 ))GB, Current free disk space for build: $(( ((FREEDISKSPACE_BUILDSPACE+1023) /1024 + 1023) /1024 ))GB"
    echolog -e "Temporary folders in ramdisk: $RAMDISKED_TEMP_FOLDERS / Total temporary folders: $TOTAL_TEMP_FOLDERS . For all temporary folders to be in RAM, $(( ((OPTIMAL_FREE_RAM+1023) /1024 + 1023) /1024 ))GB is needed to be free.\n"
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

  #Make a list of all current items under srcbuild
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/inactive_packages
  if [[ $(ls -A "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/inactive_packages/) ]]
  then
    rm "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/inactive_packages/*
  fi
  find "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/ -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -v ^buildoutput$ | grep -v ^buildhome$ | while read -r PACKAGE
  do
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/inactive_packages/"$PACKAGE"
  done

  if [[ $BUILD_SNAPSHOT_SYSTEMS == 1 && $RAMDISK_FOR_PHASE1 == 1 && $RAMDISK_STATUS == 0 ]]
  then
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/snapshot_phase_1
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork_phase1
    mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/snapshot_phase_1 "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_1
  fi

  if [[ $BUILD_SNAPSHOT_SYSTEMS == 1 && $RAMDISK_FOR_PHASE2 == 1 && $RAMDISK_STATUS == 0 ]]
  then
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/snapshot_phase_2
    mount --bind "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/snapshot_phase_2 "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2
  fi

  if [[ $RAMDISK_FOR_SRCBUILD == 1 && $RAMDISK_STATUS == 0 ]]
  then
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk/unionwork_srcbuild
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

  #Create a miniature /dev so that, for instance LVM doesn't try to create a backup file
  #on the chroots
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/minidev
  mount -t tmpfs -o size=5M none "$BUILDLOCATION"/build/"$BUILDARCH"/minidev
  if [[ $? != 0 ]]
  then
    faillog "Failed to create mini devtmpfs"
  fi
  #Use #https://www.linuxfromscratch.org/lfs/view/6.1/chapter06/devices.html
  #for the list of devices, permissions, and makor and minor numbers
  mknod -m 622 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/console c 5 1
  mknod -m 666 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/null c 1 3
  mknod -m 666 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/zero c 1 5
  mknod -m 666 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/ptmx c 5 2
  mknod -m 666 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/tty c 5 0
  mknod -m 444 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/random c 1 8
  mknod -m 444 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/urandom c 1 9
  chown root:tty "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/console
  chown root:tty "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/ptmx
  chown root:tty "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/tty
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/pts
  mount -t devpts -o gid=4,mode=620 none "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/pts
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/shm
  mount -t tmpfs none "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/shm
  ln -s /proc/self/fd "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/fd
  ln -s /proc/self/fd/0 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/stdin
  ln -s /proc/self/fd/1 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/stdout
  ln -s /proc/self/fd/2 "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/stderr

  #Copy external builders into thier own directory, make them executable
  cp -r "$SCRIPTFOLDERPATH"/externalbuilders/* "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders

  #Copy all external files before they are used
  rsync -CKr -- "$SCRIPTFOLDERPATH"/"$BUILDUNIXNAME"_files/* "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
  rsync -CKr -- "$SCRIPTFOLDERPATH"/* "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource

  #Support importing the control file to use fixed revisions of the source code
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt > /dev/null 2>&1
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME/tmp/buildcore_revisions.txt > /dev/null 2>&1
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/tmp/buildcore_revisions.txt > /dev/null 2>&1
  rm "$BUILDLOCATION"/build/"$BUILDARCH"/phase_3/tmp/buildcore_revisions.txt > /dev/null 2>&1
  if [ -s "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt ]
  then
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/
    cp "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/buildcore_revisions.txt
    rm "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt
    touch "$BUILDLOCATION"/buildcore_revisions_"$BUILDARCH".txt
  fi

  #If there is a date specified in the revisions file, create the Debian snapshot sources.list for that time
  #If using a revisions file, force downloading a snapshot from the time specified
  if [[ $APTFETCHDATESECONDS == [0-9]* ]]
  then
    APTFetchDate=$(date -d @$APTFETCHDATESECONDS -u +%Y%m%dT%H%M%SZ 2>/dev/null)
    APTFetchDateResult=$?
    if [[ $APTFetchDateResult == 0 ]]
    then
      cat "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/etc/apt/sources.list | grep ^deb | while read -r APTSourceLine
      do
        APTSourceElements=($APTSourceLine)
        APTURL=${APTSourceElements[1]}
        IFS="/"
        APTURLElements=($APTURL)
        unset IFS
        APTURLElementsCount=${#APTURLElements[@]}
        APTURLElements[2]="snapshot.debian.org/archive"
        APTURLElements[$APTURLElementsCount]=$APTFetchDate
        NewURL=$(IFS="/" ; echo "${APTURLElements[*]}")
        APTSourceElements[1]=$NewURL
        echo "${APTSourceElements[@]}"
      done >> "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/tmp/etc_apt_sources.list
    else
      echolog "Invalid APTFETCHDATESECONDS set. Falling back"
    fi
  fi

  #Delete the list of pacakges specified in RestartPackageList_"$BUILDARCH".txt
  cat "$BUILDLOCATION"/RestartPackageList_"$BUILDARCH".txt | while read -r RESETPACKAGE
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

  #Cleanup permissions on imported files, leaving only the executable bit 
  chmod u=rwX,g=rX,o=rX,a-st -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/

  find "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/ -type d | while read -r DIRECTORY
  do
    chmod 0755 "$DIRECTORY"
  done
  chown  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/
  chgrp  root  -R "$BUILDLOCATION"/build/"$BUILDARCH"/importdata/

  PREPARE_ENDTIME=$(date +%s)

  #Create a log folder for the phase logs
  mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/externallogs

  #Force buildcore to redownload cargocache if the control file is gone
  if [[ ! -e "$BUILDLOCATION"/DontRestartCargoDownload"$BUILDARCH" ]]
  then

    if [[ -e "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/cargocache ]]
    then
      echolog "Deleting downloaded Cargo files..."
      rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/cargocache
    fi

    touch "$BUILDLOCATION"/DontRestartCargoDownload"$BUILDARCH"
  fi

  #Force buildcore to redownload rust if the control file is gone
  if [[ ! -e "$BUILDLOCATION"/DontRestartRustDownload"$BUILDARCH" ]]
  then
    if [[ -e "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/buildcore_rust ]]
    then
      echolog "Deleting downloaded version of Rust..."
      rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/buildcore_rust
    fi
    touch "$BUILDLOCATION"/DontRestartRustDownload"$BUILDARCH"
  fi

  BUILD_RUNNING=1
  #run the build scripts
  if [[ $RUN_PHASE_0 == 1 ]]
  then
    PHASE0_STARTTIME=$(date +%s)
    echolog "Starting phase0..."
    NAMESPACE_EXECUTE 1 "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/externallogs/phase0.log "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase0.sh
    PHASE0_ENDTIME=$(date +%s)
  fi

  PHASE1_STARTTIME=$(date +%s)
  echolog "Starting phase1..."
  NAMESPACE_EXECUTE 1 "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/externallogs/phase1.log "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase1.sh
  PHASE1_ENDTIME=$(date +%s)

  #copy the installs data copied in phase 1 into phase 2
  rm -rf "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/var/lib/apt/lists/*
  cp "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME/tmp/INSTALLS.txt "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/tmp/INSTALLS.txt
  cp "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME/tmp/POSTREMOVES.txt "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/tmp/POSTREMOVES.txt
  cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME/var/cache/apt/*.bin "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/var/cache/apt
  cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME/var/lib/apt/lists "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/var/lib/apt

  #Copy the APTFETCHDATE file, it is for snapshots, and it is also generated on the fly for determining the date version stamp on generated .deb files
  cp "$BUILDLOCATION"/build/"$BUILDARCH"/"$PHASE1_PATHNAME"/tmp/APTFETCHDATE "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME/tmp/APTFETCHDATE

  #Remove Phase 1 if it's a snapshot
  if [[ $BUILD_SNAPSHOT_SYSTEMS == 1 ]]
  then
    echolog "Clearing phase1 snapshot build system..."
    rm -rf  "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_1/*
    mkdir -p "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2/tmp
    touch "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2/tmp/INSTALLS.txt.lastrun
  fi

  PHASE2_STARTTIME=$(date +%s)
  echolog "Starting phase2..."
  NAMESPACE_EXECUTE 0 "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/externallogs/phase2.log "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase2.sh
  PHASE2_ENDTIME=$(date +%s)

  PHASE3_STARTTIME=$(date +%s)
  echolog "Starting phase3..."
  NAMESPACE_EXECUTE 0 "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/externallogs/phase3.log "$BUILDLOCATION"/build/"$BUILDARCH"/externalbuilders/"$BUILDUNIXNAME"_phase3.sh
  PHASE3_ENDTIME=$(date +%s)

  #Main Build Complete, Extract ISO and logs


  #If the live cd did not build then tell user  
  echolog "Moving built ISO files..."

  EXPORT_STARTTIME=$(date +%s)
  #Take a snapshot of the source

  if [[ -e "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_Source_"$BUILDARCH".tar.gz ]]
  then
    rm "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_Source_"$BUILDARCH".tar.gz
  fi

  #Pack the source into a tar file, trying to always get the same filehash
  TARDATESTAMP=$(cat "$BUILDLOCATION"/build/"$BUILDARCH"/"$PHASE2_PATHNAME"/tmp/APTFETCHDATE | grep -v ^$| awk -F = '{print $2}')
  GZIP=-n tar -czvf "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_Source_"$BUILDARCH".tar.gz -C "$BUILDLOCATION"/build/"$BUILDARCH"/exportsource/ . --mtime=@$TARDATESTAMP &>/dev/null

  if [[ ! -f "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/custom-full.iso ]]
  then  
    ISOFAILED=1
  else
    mv "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/custom-full.iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_DevDbg_"$BUILDARCH".iso
  fi 
  if [[ ! -f "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/custom.iso ]]
  then  
    ISOFAILED=1
  else
    mv "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/custom.iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_"$BUILDARCH".iso
  fi 

  #Before the rest of the files are cleaned, export the logs, that are now also generated by the cleanup of the build source.
  #Create a date string for unique log folder names
  ENDDATE=$(date +"%Y-%m-%d_%H-%M-%S")

  #Create a folder contain the revisions files
  mkdir -p "$BUILDLOCATION"/revisions_history

  #Create a folder for the log files with the date string
  mkdir -p "$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH"

  #Export the log files to the location
  cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/buildlogs/* "$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH"
  rm "$BUILDLOCATION"/logs/latest-"$BUILDARCH" 2>/dev/null
  ln -s "$BUILDLOCATION"/logs/"$ENDDATE"_"$BUILDARCH" "$BUILDLOCATION"/logs/latest-"$BUILDARCH"
  cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/buildcore_revisions.txt "$BUILDLOCATION"/revisions_history/"$BUILDFRIENDLYNAME"_Revisions_"$BUILDARCH"_"$ENDDATE".txt
  cp -a "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys/buildcore_revisions.txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_Revisions_"$BUILDARCH".txt

  #allow the user to actually read the iso
  if [[ ! -z $CALLING_SUDO_USER ]]
  then
    chown $CALLING_SUDO_USER "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".tar.gz
    chgrp $CALLING_SUDO_USER "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".tar.gz
    chmod 777 "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".txt "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"_*_"$BUILDARCH".tar.gz
  fi
  EXPORT_ENDTIME=$(date +%s)


  echolog "Cleaning up non reusable build data..."  
  POSTCLEANUP_STARTTIME=$(date +%s)

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
  if [[ $RAMDISK_FOR_PHASE1 == 1 && $RAMDISK_STATUS == 0 ]]
  then
    umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE1_PATHNAME
  fi
  if [[ $RAMDISK_FOR_PHASE2 == 1 && $RAMDISK_STATUS == 0 ]]
  then
    umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/$PHASE2_PATHNAME
  fi
  if [[ $RAMDISK_FOR_REMASTERSYS == 1 && $RAMDISK_STATUS == 0 ]]
  then
    umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/remastersys
  fi
  if [[ $RAMDISK_STATUS == 0 ]]
  then
    umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/ramdisk
  fi

  #Unmount the minidevfs
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/pts
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/minidev/shm
  umount -lf "$BUILDLOCATION"/build/"$BUILDARCH"/minidev


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
  if [[ $BUILD_SNAPSHOT_SYSTEMS == 1 ]]
  then
    rm -rf  "$BUILDLOCATION"/build/"$BUILDARCH"/snapshot_phase_2/*
  fi

  rm "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile

  POSTCLEANUP_ENDTIME=$(date +%s)
  #If the live cd did  build then tell user   
  if [[ $ISOFAILED != 1  ]];
  then  
    echolog "Live CD image build was successful."
  else
    echolog "The Live CD did not succesfuly build. The script could have been modified, or a network connection could have failed to one of the servers preventing the installation packages for Debian, or Remstersys from installing. There could also be a problem with the selected architecture for the build, such as an incompatible kernel or CPU, or a misconfigured qemu-system bin_fmt"
    EXITSTATUS=1
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

  LIST=$(find "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/buildhome/inactive_packages/ -mindepth 1 -maxdepth 1 -type f -printf "%f\n" | sort | tr '\n' ' ')
  if [[ ! -z $LIST ]]
  then
    echolog -e "\nExtra packages found under "$BUILDLOCATION"/build/"$BUILDARCH"/srcbuild/ that were not used"
    echolog "$LIST"
    echolog " "
  fi


  if [[ -e "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/package_operations/phase_1/failedpackages.log ]]
  then
    echolog -e "\nPackages and operations that failed to download in phase 1:"
    LIST=$(cat "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/package_operations/phase_1/failedpackages.log | tr '\n' ' ')
    echolog "$LIST"
    echolog " "
  fi

  if [[ -e "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/package_operations/phase_2/failedpackages.log ]]
  then
    echolog -e "\nPackages and operations that failed to install in phase 2:"
    LIST=$(cat "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/package_operations/phase_2/failedpackages.log | tr '\n' ' ')
    echolog "$LIST"
    echolog " "
  fi

  if [[ -e "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/build_core/faileddownloads ]]
  then
    echolog -e "\nPackages that failed to download source:"
    LIST=$(cat "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/build_core/faileddownloads | tr '\n' ' ')
    echolog "$LIST"
    echolog " "
  fi

  if [[ -e "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/build_core/failedcompiles ]]
  then
    echolog -e "\nPackages that failed to compile:"
    LIST=$(cat "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/build_core/failedcompiles | tr '\n' ' ')
    echolog "$LIST"
    echolog " "
  fi

  echolog "ISO sizes:"
  if [[ $(compgen -G "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso &> /dev/null; echo $?) == 0 ]]
  then
    echolog "$(ls -lh "$HOMELOCATION"/"$BUILDFRIENDLYNAME"/"$BUILDFRIENDLYNAME"*_"$BUILDARCH".iso)"
  fi

  #Write specially logged messages to the mainlog
  echo "$LOGTEXT" > "$BUILDLOCATION"/logs/latest-"$BUILDARCH"/externallogs/mainlog.log

  #Remove the process from the cgroup, and clean up the cgroup
  echo $$ > ${OriginalCgroup}/cgroup.procs
  rmdir /sys/fs/cgroup/machine.slice/"$BUILDUNIXNAME"_builder:"$BUILDARCH"

  exit $EXITSTATUS
}

function define_config
{
  BUILDROOT=/var/cache
  BUILDFOLDERNAME=RBOS_Build_Files

  export BUILDUNIXNAME=rebeccablackos
  export BUILDFRIENDLYNAME=RebeccaBlackOS

  #Values for determining how much free disk/ramdisk space is needed
  GIGABYTE=1048576
  STORAGESIZE_TOTALSIZE=0
  STORAGESIZE_PADDING=$((2 * $GIGABYTE ))

  STORAGESIZE_TMPBASEBUILD=$((1 * $GIGABYTE ))
  STORAGESIZE_TMPSRCBUILDOVERLAY=$((2 * $GIGABYTE ))
  STORAGESIZE_TMPPHASE3=$((2 * $GIGABYTE ))
  STORAGESIZE_TMPREMASTERSYS=$((7 * $GIGABYTE ))


  STORAGESIZE_ISOOUT=$((4 * $GIGABYTE ))
  STORAGESIZE_BUILDOUTPUT=$((2 * $GIGABYTE ))
  STORAGESIZE_PHASE1=$((2 * $GIGABYTE ))
  STORAGESIZE_PHASE2=$((5 * $GIGABYTE ))
  STORAGESIZE_ARCHIVES=$((1 * $GIGABYTE ))
  STORAGESIZE_SRCBUILD=$((38 * $GIGABYTE ))
}

function elevate_buildprocess
{
  export BUILDER_IS_UNSHARED=1
  sudo -E -- systemd-inhibit --who="Live CD Builder (PID $$)" --why="Compiling packages for, and building the $BUILDFRIENDLYNAME ISOs" --what=sleep:shutdown -- unshare --mount "$0" "$@"
  exit $?
}

function execute_buildprocess
{
  #Start the build process
  if [[ $BUILDER_IS_UNSHARED != 1 ]]
  then
    define_config
    elevate_buildprocess "$@"
  else
    setup_buildprocess
    run_buildprocess "$@"
  fi
  exit $?
}

execute_buildprocess "$@"
