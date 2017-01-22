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

#This is a script for mounting a Ubuntu live CD, or live CD with Casper, and creating a chroot session.


trap 'kill -9 $ROOTPID; mv "$MOUNTISO.old" "${MOUNTISO}"; exit' 2


#Define the command for entering the namespace now that $ROOTPID is defined
function NAMESPACE_ENTER {
  nsenter --mount --target $ROOTPID --pid --target $ROOTPID "$@"
}

MOUNTISO=$(readlink -f $1)
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

#Determine how the script should run itself as root, with kdesudo if it exists, with gksudo if it exists, or just sudo
if [[ $UID != 0 || -z $SUDO_USER ]]
then
  if [[ $XALIVE == 0 ]]
  then
    if [[ -f $(which kdesudo) ]]
    then
      kdesudo $0 "$MOUNTISO"
    elif [[ -f $(which gksudo) ]]
    then
      gksudo $0 "$MOUNTISO"
    else
      zenity --info --text "This Needs to be run as root, via sudo, and not through a root login"
    fi
  else
    sudo $0 "$MOUNTISO"
  fi
  exit
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
  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "Cant find a install utility."
  else
    echo "Cant find a install utility."
  fi
  exit
fi

#Determine the terminal to use
if [[ $XALIVE == 0 ]]
then
  unset DBUS_SESSION_BUS_ADDRESS
  if [[ -f $(which konsole) ]]
  then
    TERMCOMMAND="konsole --nofork -e"
  elif [[ -f $(which gnome-terminal) ]]
  then
    TERMCOMMAND="gnome-terminal -e"
  else
    TERMCOMMAND="xterm -e"
    if [[ ! -f $(which xterm) ]]
    then
      zenity --question --text "xterm is needed for this script. Install xterm?"  
      xterminstall=$?
      if [[ $xterminstall -eq 0 ]]
      then 
        $INSTALLCOMMAND xterm -y
      else
        zenity --info --text "Can not continue without xterm. Exiting the script."
        exit
      fi
    fi
  fi
fi

if [[ $XALIVE == 0 ]]
then
  zenity --info --text "This will remaster the specified ISO, to install non-free firmware packages"
else
  echo "This will remaster the specified ISO, to install non-free firmware packages"
  read a
fi




#enter users home directory
cd "$MOUNTHOME"

#install needed tools
if [[ $XALIVE == 0 ]]
then
  if ! type zenity &> /dev/null
  then
    $TERMCOMMAND $INSTALLCOMMAND zenity
  fi
else
  if ! type zenity &> /dev/null
  then
    $INSTALLCOMMAND zenity
  fi
fi

#make the folders for mounting the ISO
mkdir -p "$MOUNTHOME"/isorebuild/isomount
mkdir -p "$MOUNTHOME"/isorebuild/squashfsmount
mkdir -p "$MOUNTHOME"/isorebuild/overlay
mkdir -p "$MOUNTHOME"/isorebuild/unionmountpoint


#if there is no iso specified 
if [ -z "$MOUNTISO" ]
then 

  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "No ISO specified as an argument. Please select one in the next dialog."
    MOUNTISO=$(zenity --file-selection)
  else
    echo "


Please specify a path to an ISO as an argument to this script (with quotes around the path if there are spaces in it)"
    exit
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
mv "$MOUNTISO" "${MOUNTISO}.old"
NAMESPACE_ENTER mount -o loop "${MOUNTISO}.old" "$MOUNTHOME"/isorebuild/isomount


#if the iso doesn't have a squashfs image
if [ $( NAMESPACE_ENTER test -f "$MOUNTHOME"/isorebuild/isomount/casper/filesystem.squashfs; echo $? ) != 0  ]
then
  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "Invalid CDROM image. Not an Ubuntu or Casper based image. Exiting and unmounting the image."
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
    zenity --info --text "ISO not prepared to rebuild itself (no remastersys binary) Exiting..."
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
NAMESPACE_ENTER cp /etc/resolv.conf "$MOUNTHOME"/isorebuild/unionmountpoint/etc
NAMESPACE_ENTER sed -i 's/main/main non-free/g' "$MOUNTHOME"/isorebuild/unionmountpoint/etc/apt/sources.list
NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint apt-get update
NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint apt-get install -y firmware-misc-nonfree firmware-linux-nonfree
NAMESPACE_ENTER chroot "$MOUNTHOME"/isorebuild/unionmountpoint remastersys dist


#Move out old ISO
NAMESPACE_ENTER mv "$MOUNTHOME"/isorebuild/unionmountpoint/home/remastersys/remastersys/custom.iso "$MOUNTISO"

#Delete the old ISO
if [[ -e "$MOUNTISO" ]]
then
  rm "${MOUNTISO}.old"
  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "ISO creation successful!"
  else
    echo "ISO creation successful!"
  fi
else 
  mv "$MOUNTISO.old" "${MOUNTISO}"
  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "ISO creation Failed!"
  else
    echo "ISO creation Failed!"
  fi
fi

echo "Cleaning up..."
#Kill the namespace's PID 1

kill -9 $ROOTPID

rm -rf "$MOUNTHOME"/isorebuild/overlay

exit
