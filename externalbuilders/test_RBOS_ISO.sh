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

function mountisoexit() 
{
if [[ -f "$MOUNTHOME"/liveisotest/online ]]
then
  if [[ $XALIVE == 0 ]]
  then
    zenity --question --text "Do you want to leave the virtual images mounted? If you answer no, the programs you opened from the image, or programs accessing files on the image will be terminated"
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
    rm "$MOUNTHOME"/liveisotest/namespacepid1
    rm "$MOUNTHOME"/liveisotest/online

    if [[ $XALIVE == 0 ]]
    then
      zenity --question --text "Keep Temporary overlay files?"
      deleteanswer=$?
    else
      dialog --stdout --yesno "Keep Temporary overlay files?" 30 30
      deleteanswer=$?
    fi
    if [ $deleteanswer -eq 1 ]
    then 
      rm -rf "$MOUNTHOME"/liveisotest/overlay
      rm "$MOUNTHOME"/liveisotest/firstrun
    fi
  fi
fi
exit
}


if [[ $XALIVE == 0 ]]
then
  zenity --info --text "This will call a chroot shell from an iso.

  The password for the test user is the same password as the sudo users."
else
  echo "This will call a chroot shell from an iso.

The password for the test user is the same password as the sudo users.

Press enter"
  read a
fi




#enter users home directory
cd "$MOUNTHOME"

#Get any saved PID from a created namespace, see if the ISO is mounted in the namespace
ROOTPID=$(cat "$MOUNTHOME"/liveisotest/namespacepid1)
#If the namespace root pid exists, and is stored
if [[ -e /proc/$ROOTPID && ! -z $ROOTPID ]]
then

    NAMESPACE_ENTER mountpoint "$MOUNTHOME"/liveisotest/unionmountpoint
    ismount=$?
else
    ismount=1
fi

if [ $ismount -eq 0 ]
then

  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "A script is running that is already testing an ISO. will now chroot into it"
    $TERMCOMMAND nsenter --mount --target $ROOTPID --pid --target $ROOTPID  chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
  else
    echo "A script is running that is already testing an ISO. will now chroot into it"
    echo "Type exit to go back to your system."
    NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
  fi
  mountisoexit
fi

#install needed tools to allow testing on a read only iso
if [[ $XALIVE == 0 ]]
then
  if [[ $HASOVERLAYFS == 0 ]]
  then
    if ! type unionfs-fuse &> /dev/null
    then
      $TERMCOMMAND $INSTALLCOMMAND unionfs-fuse
    fi
  fi
  
  if ! type dialog &> /dev/null
  then
    $TERMCOMMAND $INSTALLCOMMAND dialog
  fi


  if ! type zenity &> /dev/null
  then
    $TERMCOMMAND $INSTALLCOMMAND zenity
  fi

else
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
fi

#make the folders for mounting the ISO
mkdir -p "$MOUNTHOME"/liveisotest/isomount
mkdir -p "$MOUNTHOME"/liveisotest/squashfsmount
mkdir -p "$MOUNTHOME"/liveisotest/overlay
mkdir -p "$MOUNTHOME"/liveisotest/unionmountpoint


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
echo $ROOTPID > "$MOUNTHOME"/liveisotest/namespacepid1

#Ensure that all the mountpoints in the namespace are private, and won't be shared to the main system
NAMESPACE_ENTER mount --make-rprivate /

#mount the ISO
NAMESPACE_ENTER mount -o loop "$MOUNTISO" "$MOUNTHOME"/liveisotest/isomount


#if the iso doesn't have a squashfs image
if [ $( NAMESPACE_ENTER test -f "$MOUNTHOME"/liveisotest/isomount/casper/filesystem.squashfs; echo $? ) != 0  ]
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


#mount the squashfs image
NAMESPACE_ENTER mount -o loop "$MOUNTHOME"/liveisotest/isomount/casper/filesystem.squashfs "$MOUNTHOME"/liveisotest/squashfsmount

#Create the union between squashfs and the overlay
if [[ $HASOVERLAYFS == 0 ]]
then
  NAMESPACE_ENTER unionfs-fuse -o cow,use_ino,suid,dev,default_permissions,allow_other,nonempty,max_files=131068 "$MOUNTHOME"/liveisotest/overlay=RW:"$MOUNTHOME"/liveisotest/squashfsmount "$MOUNTHOME"/liveisotest/unionmountpoint
else
  mkdir -p "$MOUNTHOME"/liveisotest/unionwork
  NAMESPACE_ENTER mount -t overlay overlay -o lowerdir="$MOUNTHOME"/liveisotest/squashfsmount,upperdir="$MOUNTHOME"/liveisotest/overlay,workdir="$MOUNTHOME"/liveisotest/unionwork "$MOUNTHOME"/liveisotest/unionmountpoint
fi

#bind mount in the critical filesystems
NAMESPACE_ENTER mount --rbind /sys "$MOUNTHOME"/liveisotest/unionmountpoint/sys

NAMESPACE_ENTER mount --rbind /proc "$MOUNTHOME"/liveisotest/unionmountpoint/proc

NAMESPACE_ENTER mount --rbind /dev "$MOUNTHOME"/liveisotest/unionmountpoint/dev

NAMESPACE_ENTER mount --bind /tmp "$MOUNTHOME"/liveisotest/unionmountpoint/tmp
NAMESPACE_ENTER mkdir -p "$MOUNTHOME"/liveisotest/unionmountpoint/run/shm
NAMESPACE_ENTER mount --bind /run/shm "$MOUNTHOME"/liveisotest/unionmountpoint/run/shm
#allow all local connections to the xserver
#xhost +LOCAL:

#allow testuser to access the system
#setfacl -m u:$SUDO_UID:rwx /dev/dri/card*

#tell the user how to exit chroot
if [[ $XALIVE == 0 ]]
then
  zenity --info --text "Type exit into the terminal window that will come up after this dialog when you want to unmount the ISO image"
else
  echo "
Type exit to go back to your system"
fi

#Only configure the system once
if [[ ! -f "$MOUNTHOME"/liveisotest/firstrun ]]
then
  touch "$MOUNTHOME"/liveisotest/firstrun

  #Configure test system
  NAMESPACE_ENTER mkdir -p  "$MOUNTHOME"/liveisotest/unionmountpoint/run/user/$SUDO_UID
  NAMESPACE_ENTER chmod 700 "$MOUNTHOME"/liveisotest/unionmountpoint/run/user/$SUDO_UID
  NAMESPACE_ENTER chown $SUDO_UID "$MOUNTHOME"/liveisotest/unionmountpoint/run/user/$SUDO_UID
  NAMESPACE_ENTER ln -s /proc/mounts "$MOUNTHOME"/liveisotest/unionmountpoint/etc/mtab
  NAMESPACE_ENTER rm "$MOUNTHOME"/liveisotest/unionmountpoint/etc/resolv.conf
  NAMESPACE_ENTER cp /etc/resolv.conf "$MOUNTHOME"/liveisotest/unionmountpoint/etc
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint groupadd -g $SUDO_UID livetest
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint groupadd -r admin 
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint groupadd -r sudo
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint /usr/sbin/useradd -g livetest -m -p $(cat /etc/shadow|grep ^$SUDO_USER: | awk -F : '{print $2}') -s /bin/bash -G admin,plugdev,sudo -u $SUDO_UID livetest 
  NAMESPACE_ENTER mkdir -p "$MOUNTHOME"/liveisotest/unionmountpoint/var/run/dbus
  #give more information in the testuser .bashrc
  echo "
echo \"
Weston Session commands:
nested-defaultweston-caller
nested-liri-caller
nested-orbital-caller
nested-enlightenment-caller
nested-gnomeshell-caller
nested-kdeplasma-caller

NOTE: Any commands entered in this tab will effect the mounted system.
If this terminal program that is running in this window supports tabs, any new tabs will be running as root to your real system.
Exercise caution. Even some paticular commands run in here can effect your real system.\"" | NAMESPACE_ENTER tee -a "$MOUNTHOME"/liveisotest/unionmountpoint/home/livetest/.bashrc > /dev/null
  echo 'cd $(eval echo ~$LOGNAME)' | NAMESPACE_ENTER tee -a "$MOUNTHOME"/liveisotest/unionmountpoint/home/livetest/.bashrc > /dev/null
fi
  
if [[ ! -f "$MOUNTHOME"/liveisotest/online ]]
then
  touch "$MOUNTHOME"/liveisotest/online

  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint dbus-daemon --system --fork
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint upower &
fi

if [[ $XALIVE == 0 ]]
then
  $TERMCOMMAND nsenter --mount --target $ROOTPID --pid --target $ROOTPID chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
else
  NAMESPACE_ENTER chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
fi

#go back to the users home folder
cd "$MOUNTHOME"


mountisoexit
