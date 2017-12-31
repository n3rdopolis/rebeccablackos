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

#This is a script for mounting a Ubuntu live CD, or live CD with Casper, and creating a chroot session.


trap 'kill -9 $ROOTPID; exit' 2


#Define the command for entering the namespace now that $ROOTPID is defined
function NAMESPACE_ENTER {
  nsenter --mount --target $ROOTPID --pid --target $ROOTPID "$@"
}

if [[ -f $(which zenity) ]]
then
  ZENITYCOMMAND="sudo -u $SUDO_USER zenity"
else
  ZENITYCOMMAND=""
fi

MOUNTISO=$(readlink -f "$1")
MOUNTISOPATH=$(dirname "$MOUNTISO")
MOUNTISONAME=$(basename -s ".iso" "$MOUNTISO")
NEWISO="${MOUNTISOPATH}/${MOUNTISONAME}_nonfree.iso"

XALIVE=$(xprop -root>/dev/null 2>&1; echo $?)
HASOVERLAYFS=$(grep -c overlay$ /proc/filesystems)
if [[ $HASOVERLAYFS == 0 ]]
then
  HASOVERLAYFSMODULE=$(modprobe -n overlay; echo $?)
  if [[ $HASOVERLAYFSMODULE == 0 ]]
  then
    HASOVERLAYFS=1
  fi
fi


#Determine the size of the ram disk
FREERAM=$(grep MemAvailable: /proc/meminfo | awk '{print $2}')
if [[ $FREERAM -gt 10000000 ]]
then
  RAMDISK_FOR_OVERLAY=1
  RAMDISKSIZE=8000000
fi

export HOME=$(eval echo ~$SUDO_USER)
MOUNTHOME="$HOME"

#Determine the terminal to use
if [[ $XALIVE == 0 ]]
then
  unset DBUS_SESSION_BUS_ADDRESS
  if [[ -f $(which konsole) ]]
  then
    TERMCOMMAND="konsole --separate -e"
  elif [[ -f $(which gnome-terminal) ]]
  then
    TERMCOMMAND="gnome-terminal -e"
  else
    TERMCOMMAND="x-terminal-emulator -e"
    if [[ ! -f $(readlink -f $(which x-terminal-emulator ) 2>/dev/null) ]]
    then
      TERMCOMMAND=""
    fi
  fi
fi

#Fallback to terminal mode if zenity or (gnome terminal/konsole/x-terminal-emulator) is not installed or configured
if [[ $TERMCOMMAND == "" || $ZENITYCOMMAND == "" ]]
then
  if [[ $XALIVE == 0 ]]
  then
    echo "Zentity or Terminal emulator not found, please install Zenity, and a terminal emulator"
    XALIVE=1
  fi
fi

#Determine how the script should run itself as root, with kdesudo if it exists, with gksudo if it exists, or just sudo
if [[ $UID != 0 || -z $SUDO_USER ]]
then
  if [[ $XALIVE == 0 ]]
  then
    $TERMCOMMAND "bash -c \"sudo -E "$0" "$MOUNTISO" 2>/dev/null\""
    exit
  else
    sudo -E "$0" "$MOUNTISO"
    exit
  fi

fi


#Try to determine the package manager.
if [[ -f $(which apt-get) ]]
then
  INSTALLCOMMAND="apt-get install"
elif [[ -f $(which yum) ]]
then
  INSTALLCOMMAND="yum install"
elif [[ -f $(which pacman) ]]
then
  INSTALLCOMMAND="pacman -S"
elif [[ -f $(which zypper) ]]
then
  INSTALLCOMMAND="zypper in"
elif [[ -f $(which up2date) ]]
then
  INSTALLCOMMAND="up2date -i"
elif [[ -f $(which urpmi) ]]
then
  INSTALLCOMMAND="urpmi"
else
  echo "Cant find a install utility."
  exit
fi

if ! type zenity &> /dev/null
then
  $INSTALLCOMMAND zenity
fi


if [[ $XALIVE == 0 ]]
then
  $ZENITYCOMMAND --info --text "This will remaster the specified ISO, to install non-free firmware packages
While there is no cost for these packages, these packages are closed source,
and don't have the same freedoms as the rest of the rest of the packages on these ISOs,
but may allow more hardware to work." 2>/dev/null
else
  echo "This will remaster the specified ISO, to install non-free firmware packages
While there is no cost for these packages, these packages are closed source,
and don't have the same freedoms as the rest of the rest of the packages on these ISOs
but may allow more hardware to work."
  read a
fi

FIRMWARELIST="atmel-firmware
firmware-atheros
firmware-b43-installer
firmware-b43legacy-installer
firmware-brcm80211
firmware-intelwimax
firmware-ipw2x00
firmware-iwlwifi
firmware-libertas
firmware-myricom
firmware-netxen
firmware-realtek
firmware-ti-connectivity
firmware-zd1211"

FIRMWAREUILIST=""

if [[ $XALIVE != 0 ]]
then
  while read FIRMWARE
  do
    FIRMWAREUILIST+="$FIRMWARE \"\" 0 "
  done < <(echo "$FIRMWARELIST")
  FIRMWARESELECT=$(dialog --checklist "Select Firmware:" 40 40 40 $FIRMWAREUILIST --stdout)
else
  while read FIRMWARE
  do
    if [[ $FIRMWAREUILIST != "" ]]
    then
      FIRMWAREUILIST+=$'\n'$'\n'
    else
      FIRMWAREUILIST+=$'\n'
    fi
    FIRMWAREUILIST+="$FIRMWARE"
  done < <(echo "$FIRMWARELIST")

  FIRMWARESELECT=$(echo "$FIRMWAREUILIST" | $ZENITYCOMMAND --list --text="Select Firmware:" --checklist --separator=" " --multiple --hide-header --column=check --column=firmware 2>/dev/null)
fi
FIRMWARESELECT=$(echo "$FIRMWARESELECT"| sed 's/ /\n/g')

#enter users home directory
cd "$MOUNTHOME"

#make the folders for mounting the ISO
mkdir -p "$MOUNTHOME"/isorebuild/isomount
mkdir -p "$MOUNTHOME"/isorebuild/squashfsmount
mkdir -p "$MOUNTHOME"/isorebuild/overlay
mkdir -p "$MOUNTHOME"/isorebuild/unionmountpoint


#Detect another instance, by creating a testing a lockfile, which is a symlink to /proc/pid/cmdline, and making sure the second line of /proc/pid/cmdline matches (as it's the path to the script).
ls $(readlink -f "$MOUNTHOME"/isorebuild/lockfile) &> /dev/null
result=$?
if [[ $result != 0 || ! -e "$MOUNTHOME"/isorebuild/lockfile  ]]
then
  rm "$MOUNTHOME"/isorebuild/lockfile &> /dev/null
  "$BUILDLOCATION"/build/"$BUILDARCH"/lockfile 2>/dev/null
  ln -s /proc/"$$"/cmdline "$MOUNTHOME"/isorebuild/lockfile
else
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "Another instance is already running" 2>/dev/null
  else
    echo "Another instance is already running"
  fi
  exit
fi


#if there is no iso specified 
if [ -z "$MOUNTISO" ]
then 

  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "No ISO specified as an argument. Please select one in the next dialog." 2>/dev/null
    MOUNTISO=$($ZENITYCOMMAND --file-selection 2>/dev/null)
  else
    dialog --msgbox "File navigation: To navigate directories, select them with the cursor, and press space twice. To go back, go into the text area of the path, and press backspace. To select a file, select it with the cursor, and press space"  20 60
    MOUNTISO=$(dialog --fselect "$MOUNTHOME"/ 20 60 --stdout)
  fi
fi

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
if [[ -z $ROOTPID ]]
then
  echo "The main namespace process failed to start, in 1 minute. This should not take that long"
  exit
fi

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
NAMESPACE_ENTER mount --make-rprivate /

#mount the ISO

NAMESPACE_ENTER mount -o loop "${MOUNTISO}" "$MOUNTHOME"/isorebuild/isomount


#if the iso doesn't have a squashfs image
if [ $( NAMESPACE_ENTER test -f "$MOUNTHOME"/isorebuild/isomount/casper/filesystem.squashfs; echo $? ) != 0  ]
then
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "Invalid CDROM image. Not an Ubuntu or Casper based image. Exiting and unmounting the image." 2>/dev/null
  else
    echo "Invalid CDROM image. Not an Ubuntu or Casper based image. Press enter."
    read a 
  fi

  killall -9 $ROOTPID
  exit
fi

rm -rf "$MOUNTHOME"/isorebuild/overlay


#mount the squashfs image
NAMESPACE_ENTER mount -o loop "$MOUNTHOME"/isorebuild/isomount/casper/filesystem.squashfs "$MOUNTHOME"/isorebuild/squashfsmount
REMASTERSYS_STATUS=$(NAMESPACE_ENTER ls "$MOUNTHOME"/isorebuild/squashfsmount/usr/bin/remastersys)

if [[ $REMASTERSYS_STATUS == 0 ]]
then 
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "ISO not prepared to rebuild itself (no remastersys binary) Exiting..." 2>/dev/null
  else
    echo "ISO not prepared to rebuild itself (no remastersys binary) Exiting..."
  fi
  kill -9 $ROOTPID
  exit
fi

#Mount the ramdisk
if [[ $RAMDISK_STATUS != 0 ]]
then
  mkdir -p "$MOUNTHOME"/isorebuild/ramdisk
  NAMESPACE_ENTER mount -t tmpfs -o size=${RAMDISKSIZE}k tmpfs "$MOUNTHOME"/isorebuild/ramdisk
  RAMDISK_STATUS=$?
else 
  RAMDISK_STATUS=1
fi

#Prepare the ramdisk
if [[ $RAMDISK_STATUS == 0 && $RAMDISK_FOR_OVERLAY == 1 && $HASOVERLAYFS == 1 ]]
then
  NAMESPACE_ENTER mkdir "$MOUNTHOME"/isorebuild/ramdisk/overlay
  NAMESPACE_ENTER mkdir "$MOUNTHOME"/isorebuild/ramdisk/unionwork
fi

#Create the union between squashfs and the overlay
if [[ $HASOVERLAYFS == 0 ]]
then
  echo "no overlayfs detected! Copying files..."
  cp -a "$MOUNTHOME"/isorebuild/squashfsmount/* "$MOUNTHOME"/isorebuild/overlay
else
  mkdir -p "$MOUNTHOME"/isorebuild/unionwork "$MOUNTHOME"/isorebuild/overlay/
  
  
  #Union mount phase2 and phase3
  if [ $( NAMESPACE_ENTER test -d "$MOUNTHOME"/isorebuild/ramdisk/overlay; echo $? ) == 0  ]
  then
    NAMESPACE_ENTER mount -t overlay overlay -o lowerdir="$MOUNTHOME"/isorebuild/squashfsmount,upperdir="$MOUNTHOME"/isorebuild/ramdisk/overlay,workdir="$MOUNTHOME"/isorebuild/ramdisk/unionwork "$MOUNTHOME"/isorebuild/unionmountpoint
  else
    NAMESPACE_ENTER mount -t overlay overlay -o lowerdir="$MOUNTHOME"/isorebuild/squashfsmount,upperdir="$MOUNTHOME"/isorebuild/overlay,workdir="$MOUNTHOME"/isorebuild/unionwork "$MOUNTHOME"/isorebuild/unionmountpoint
  fi
fi

#bind mount in the critical filesystems
NAMESPACE_ENTER mount --rbind /sys "$MOUNTHOME"/isorebuild/unionmountpoint/sys

NAMESPACE_ENTER mount --rbind /proc "$MOUNTHOME"/isorebuild/unionmountpoint/proc

NAMESPACE_ENTER mount --rbind /dev "$MOUNTHOME"/isorebuild/unionmountpoint/dev

NAMESPACE_ENTER mkdir -p "$MOUNTHOME"/isorebuild/unionmountpoint/run/shm
NAMESPACE_ENTER mount --bind /run/shm "$MOUNTHOME"/isorebuild/unionmountpoint/run/shm

#Install the nonfree firmware, and build a new ISO
NAMESPACE_ENTER rm "$MOUNTHOME"/isorebuild/unionmountpoint/etc/resolv.conf
NAMESPACE_ENTER cp /etc/resolv.conf "$MOUNTHOME"/isorebuild/unionmountpoint/etc/resolv.conf
NAMESPACE_ENTER sed -i 's/main/main non-free/g' "$MOUNTHOME"/isorebuild/unionmountpoint/etc/apt/sources.list
NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint apt-get update
NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint apt-get install -y firmware-misc-nonfree firmware-linux-nonfree
echo "$FIRMWARESELECT" | while read FIRMWARE
do
  NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint apt-get install -y $FIRMWARE
done
NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint remastersys dist

#Move out old ISO
NAMESPACE_ENTER mv "$MOUNTHOME"/isorebuild/unionmountpoint/home/remastersys/remastersys/custom.iso "$NEWISO"

#Delete the old ISO
if [[ -e "$NEWISO" ]]
then
  chown $SUDO_USER:$SUDO_GID "$NEWISO"
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "ISO creation successful! $NEWISO has been created." 2>/dev/null
  else
    echo "ISO creation successful! $NEWISO has been created."
  fi
else 
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "ISO creation Failed!" 2>/dev/null
  else
    echo "ISO creation Failed!"
  fi
fi

echo "Cleaning up..."
#Kill the namespace's PID 1

kill -9 $ROOTPID

rm -rf "$MOUNTHOME"/isorebuild/overlay

exit
