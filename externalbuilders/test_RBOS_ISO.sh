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

#Define the command for entering the namespace now that $ROOTPID is defined
function NAMESPACE_ENTER {
  nsenter --mount --pid --target $ROOTPID "$@"
}

if [[ -f $(which zenity) ]]
then
  ZENITYCOMMAND="sudo -u $SUDO_USER zenity"
else
  ZENITYCOMMAND=""
fi

MOUNTISO=$(readlink -f "$1")

#Identify the ISO, create a hash of the path to the ISO, so each ISO that is mounted can have its own path
#checksums of the paths are free from unsafe characters
MOUNTISOPATHHASH=( $(echo -n "$MOUNTISO" | sha1sum ))
MOUNTISOPATHHASH=isotestdir_${MOUNTISOPATHHASH[0]}

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


if [[ $HASOVERLAYFS == 0 ]]
then
  if ! type unionfs-fuse &> /dev/null
  then
    $INSTALLCOMMAND unionfs-fuse
  fi
fi

if ! type dialog &> /dev/null
then
  $INSTALLCOMMAND dialog
fi

if ! type zenity &> /dev/null
then
  $INSTALLCOMMAND zenity
fi

if ! type tmux &> /dev/null
then
  $INSTALLCOMMAND tmux
fi



function mountisoexit() 
{
if [[ -f "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/online ]]
then
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --question --text "Do you want to leave the virtual images mounted? If you answer no, the programs you opened from the image, or programs accessing files on the image will be terminated" 2>/dev/null
  unmountanswer=$?
  else
    dialog --stdout --yesno "Do you want to leave the virtual images mounted? If you answer no, the programs you opened from the image, or programs accessing files on the image will be terminated" 30 30
    unmountanswer=$?
  fi

  if [ $unmountanswer -eq 1 ]
  then
    echo "Cleaning up..."
    #set the xserver security back to what it should be
    #xhost -LOCAL:

    #don't allow access to the card for the testuser
    #setfacl -x u:$SUDO_UID /dev/dri/card*
    
    #Kill the namespace's PID 1
    kill -9 $ROOTPID
    rm "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/namespacepid1
    rm "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/online

    if [[ $XALIVE == 0 ]]
    then
      $ZENITYCOMMAND --question --text "Keep Temporary overlay files?" 2>/dev/null
      deleteanswer=$?
    else
      dialog --stdout --yesno "Keep Temporary overlay files?" 30 30
      deleteanswer=$?
    fi
    if [ $deleteanswer -eq 1 ]
    then 
      rm -rf "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/overlay
      rm "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/firstrun
      rm -rf "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH
    fi
  fi
fi
exit
}


if [[ $XALIVE == 0 ]]
then
  $ZENITYCOMMAND --info --text "This will call a chroot shell from an iso.

  The password for the test user is the same password as the sudo users." 2>/dev/null
else
  echo "This will call a chroot shell from an iso.

The password for the test user is the same password as the sudo users.

Press enter"
  read a
fi




#enter users home directory
cd "$MOUNTHOME"

#if there is no iso specified 
if [ -z "$MOUNTISO" ]
then 
  MOUNTEDSYSTEMCOUNT=$(ls "$MOUNTHOME"/liveisotest/isotestdir_*/firstrun | wc -l)

  if [[ $MOUNTEDSYSTEMCOUNT == 0 ]]
  then
    MOUNTORUSEANSWER=1
  else
    if [[ $XALIVE == 0 ]]
    then
      $ZENITYCOMMAND --question --text="Mount a new ISO, or enter an existing mounted session?" --cancel-label="New ISO" --ok-label="Enter Running Session" 2> /dev/null
      MOUNTORUSEANSWER=$?
    else
      dialog --yes-label "Enter Running Session" --no-label "New ISO" --yesno "Mount a new ISO, or enter an existing mounted session?" 20 60
      MOUNTORUSEANSWER=$?
    fi
  fi

  if [[ $MOUNTORUSEANSWER == 0 ]]
  then
    RUNNINGISOLIST=""
    while read RUNFILE
    do
      if [[ $RUNNINGISOLIST != "" ]]
      then
        RUNNINGISOLIST+=$'\n'
      fi
      RUNISO=$(cat "$RUNFILE")
      RUNNINGISOLIST+="$RUNISO"
    done < <(find "$MOUNTHOME"/liveisotest/isotestdir_*/firstrun)

    if [[ $XALIVE == 0 ]]
    then
      RUNNINGISOUILIST=""
      while read RUNNINGISO
      do
        if [[ $RUNNINGISOUILIST != "" ]]
        then
          RUNNINGISOUILIST+=$'\n'$'\n'
        else
          RUNNINGISOUILIST+=$'\n'
        fi
        RUNNINGISOUILIST+="$RUNNINGISO"
      done < <(echo "$RUNNINGISOLIST")
      MOUNTISO=$(echo "$RUNNINGISOUILIST" | $ZENITYCOMMAND --list --text="Select Mounted ISO:" --radiolist  --hide-header --column=check --column=ISO --width=400 2>/dev/null)

    else
      RUNNINGISOUILIST=()
      while read RUNNINGISO
      do
        RUNNINGISOUILIST+=("$RUNNINGISO")
        RUNNINGISOUILIST+=(" ")
        RUNNINGISOUILIST+=(0)
      done < <(echo "$RUNNINGISOLIST")
      MOUNTISO=$(dialog --radiolist "Select Mounted ISO:" 40 100 40 "${RUNNINGISOUILIST[@]}" --stdout)

    fi
  else
    if [[ $XALIVE == 0 ]]
    then
      $ZENITYCOMMAND --info --text "No ISO specified as an argument. Please select one in the next dialog." 2>/dev/null
      MOUNTISO=$($ZENITYCOMMAND --file-selection 2>/dev/null)
    else
      dialog --msgbox "File navigation: To navigate directories, select them with the cursor, and press space twice. To go back, go into the text area of the path, and press backspace. To select a file, select it with the cursor, and press space"  20 60
      MOUNTISO=$(dialog --fselect "$MOUNTHOME"/ 20 60 --stdout)
    fi
  fi
fi

#Identify the ISO, create a hash of the path to the ISO, so each ISO that is mounted can have its own path
#checksums of the paths are free from unsafe characters
MOUNTISOPATHHASH=( $(echo -n "$MOUNTISO" | sha1sum ))
MOUNTISOPATHHASH=isotestdir_${MOUNTISOPATHHASH[0]}

#Get any saved PID from a created namespace, see if the ISO is mounted in the namespace
ROOTPID=$(cat "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/namespacepid1)
#If the namespace root pid exists, and is stored
if [[ -e /proc/$ROOTPID && ! -z $ROOTPID ]]
then

    NAMESPACE_ENTER mountpoint "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint &> /dev/null
    ismount=$?
else
    ismount=1
fi

if [ $ismount -eq 0 ]
then

  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "Will now bring up a prompt for the existing system." 2>/dev/null
  else
    echo "Will now bring up a prompt for the existing system."
    echo "Type exit to go back to your system."
  fi

  TARGETBITSIZE=$(NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint /usr/bin/getconf LONG_BIT)
  if [[ $TARGETBITSIZE == 32 ]]
  then
    BITNESSCOMMAND=linux32
  elif [[ $TARGETBITSIZE == 64 ]]
  then
    BITNESSCOMMAND=linux64
  else
    echo "Unknown chroot failure, detecting the target systems bitness"
    exit
  fi

  tmux -S "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/tmuxsocket new-session nsenter --mount --pid --target $ROOTPID  $BITNESSCOMMAND chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint su livetest
  mountisoexit
fi

#make the folders for mounting the ISO
mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/isomount
mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/squashfsmount
mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/overlay
mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint

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
echo $ROOTPID > "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/namespacepid1

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
NAMESPACE_ENTER mount --make-rprivate /

#mount the ISO
NAMESPACE_ENTER mount -o loop "$MOUNTISO" "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/isomount


#if the iso doesn't have a squashfs image
if [ $( NAMESPACE_ENTER test -f "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/isomount/casper/filesystem.squashfs; echo $? ) != 0  ]
then
  if [[ $XALIVE == 0 ]]
  then
    $ZENITYCOMMAND --info --text "Invalid CDROM image. Not an Ubuntu or Casper based image. Exiting and unmounting the image." 2>/dev/null
  else
    echo "Invalid CDROM image. Not an Ubuntu or Casper based image. Press enter."
    read a 
  fi
  rm -rf "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH

  killall -9 $ROOTPID
  exit
fi


#mount the squashfs image
NAMESPACE_ENTER mount -o loop "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/isomount/casper/filesystem.squashfs "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/squashfsmount

#Create the union between squashfs and the overlay
if [[ $HASOVERLAYFS == 0 ]]
then
  NAMESPACE_ENTER unionfs-fuse -o cow,use_ino,suid,dev,default_permissions,allow_other,nonempty,max_files=131068 "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/overlay=RW:"$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/squashfsmount "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint
else
  mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionwork
  NAMESPACE_ENTER mount -t overlay overlay -o lowerdir="$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/squashfsmount,upperdir="$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/overlay,workdir="$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionwork "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint
fi

#bind mount in the critical filesystems
NAMESPACE_ENTER mount --rbind /sys "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/sys

NAMESPACE_ENTER mount --rbind /proc "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/proc

NAMESPACE_ENTER mount --rbind /dev "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/dev

NAMESPACE_ENTER mount --bind /tmp "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/tmp
NAMESPACE_ENTER mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/shm
NAMESPACE_ENTER mount --bind /run/shm "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/shm
#allow all local connections to the xserver
#xhost +LOCAL:

#allow testuser to access the system
#setfacl -m u:$SUDO_UID:rwx /dev/dri/card*

#tell the user how to exit chroot
if [[ $XALIVE == 0 ]]
then
  $ZENITYCOMMAND --info --text "Type exit into the terminal window that will come up after this dialog when you want to unmount the ISO image" 2>/dev/null
else
  echo "
Type exit to go back to your system"
fi

#Only configure the system once
if [[ ! -f "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/firstrun ]]
then
  echo -n "$MOUNTISO" > "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/firstrun

  #Configure test system
  NAMESPACE_ENTER mkdir -p  "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/user/$SUDO_UID
  NAMESPACE_ENTER chmod 700 "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/user/$SUDO_UID
  NAMESPACE_ENTER chown $SUDO_UID "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/user/$SUDO_UID
  NAMESPACE_ENTER ln -s /proc/mounts "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/etc/mtab
  NAMESPACE_ENTER rm "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/etc/resolv.conf
  NAMESPACE_ENTER cp /etc/resolv.conf "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/etc
  NAMESPACE_ENTER cp /var/lib/dbus/machine-id "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/var/lib/dbus/
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint groupadd -g $SUDO_UID livetest
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint groupadd -r admin 
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint groupadd -r sudo
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint /usr/sbin/useradd -g livetest -m -p $(cat /etc/shadow|grep ^$SUDO_USER: | awk -F : '{print $2}') -s /bin/bash -G admin,plugdev,sudo -u $SUDO_UID livetest 
  NAMESPACE_ENTER mkdir -p "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/var/run/dbus
  #give more information in the testuser .bashrc
  echo "
(export \$(dbus-launch); . /usr/bin/wlruntime_vars; /usr/bin/wlruntime_firstrun)
echo \"
Weston Session commands:
nested-defaultweston-caller
nested-gnomeshell-caller
nested-liri-caller
nested-orbital-caller
nested-enlightenment-caller
nested-kdeplasma-caller

NOTE: Any commands entered in this tab will effect the mounted system.
Please be aware of which terminal you are typing in, especially with more experimantal/risker commands.

Exercise caution. Even some paticular commands run in here can effect your real system.\"" | NAMESPACE_ENTER tee -a "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/home/livetest/.bashrc > /dev/null
  echo 'cd $(eval echo ~$LOGNAME)' | NAMESPACE_ENTER tee -a "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/home/livetest/.bashrc > /dev/null
fi
  
if [[ ! -f "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/online ]]
then
  touch "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/online
fi

#Foward the users XDG_RUNTIME_DIR for pulseaudio
NAMESPACE_ENTER mount --rbind /run/user/$SUDO_UID "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/user/$SUDO_UID
NAMESPACE_ENTER mount --rbind /run/dbus "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint/run/dbus

TARGETBITSIZE=$(NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint /usr/bin/getconf LONG_BIT)
  if [[ $TARGETBITSIZE == 32 ]]
  then
    BITNESSCOMMAND=linux32
  elif [[ $TARGETBITSIZE == 64 ]]
  then
    BITNESSCOMMAND=linux64
  else
    echo "Unknown chroot failure, detecting the target systems bitness"
    exit
  fi

tmux -S "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/tmuxsocket new-session nsenter --mount --pid --target $ROOTPID  $BITNESSCOMMAND chroot "$MOUNTHOME"/liveisotest/$MOUNTISOPATHHASH/unionmountpoint su livetest

#go back to the users home folder
cd "$MOUNTHOME"


mountisoexit
