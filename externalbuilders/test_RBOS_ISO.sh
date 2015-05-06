#! /bin/bash
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

#This is a script for mounting a Ubuntu live CD, and creating a chroot session.

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
if [[ -f "$MOUNTHOME"/liveisotest/unionmountpoint/online ]]
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

    #unmount the filesystems used by the CD
    umount -lf  "$MOUNTHOME"/liveisotest/unionmountpoint/run/shm
    umount -lf  "$MOUNTHOME"/liveisotest/unionmountpoint/dev
    umount -lf  "$MOUNTHOME"/liveisotest/unionmountpoint/sys
    umount -lf  "$MOUNTHOME"/liveisotest/unionmountpoint/proc
    umount -lf  "$MOUNTHOME"/liveisotest/unionmountpoint/tmp

    fuser -kmM   "$MOUNTHOME"/liveisotest/unionmountpoint 2> /dev/null
    umount -lfd "$MOUNTHOME"/liveisotest/unionmountpoint

    fuser -kmM   "$MOUNTHOME"/liveisotest/squashfsmount 2> /dev/null
    umount -lfd "$MOUNTHOME"/liveisotest/squashfsmount

    fuser -kmM  "$MOUNTHOME"/liveisotest/isomount 2> /dev/null
    umount -lfd "$MOUNTHOME"/liveisotest/isomount


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
    fi
  fi
  exit
fi
}


if [[ $XALIVE == 0 ]]
then
  zenity --info --text "This will call a chroot shell from an iso.

  The password for the test user is the same password as the sudo users. Just hit enter if you actually need it."
else
  echo "This will call a chroot shell from an iso.

The password for the test user is the same password as the sudo users. Just hit enter if you actually need it.

Press enter"
  read a
fi




#enter users home directory
cd "$MOUNTHOME"

mountpoint "$MOUNTHOME"/liveisotest/unionmountpoint
ismount=$?
if [ $ismount -eq 0 ]
then

  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "A script is running that is already testing an ISO. will now chroot into it"
    $TERMCOMMAND chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
  else
    echo "A script is running that is already testing an ISO. will now chroot into it"
    echo "Type exit to go back to your system."
    chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
  fi
  mountisoexit
fi

#install needed tools to allow testing on a read only iso
if [[ $XALIVE == 0 ]]
then
  if [[ $HASOVERLAYFS == 0 ]]
  then
    $TERMCOMMAND $INSTALLCOMMAND unionfs-fuse
  fi
  $TERMCOMMAND $INSTALLCOMMAND squashfs-tools
  $TERMCOMMAND $INSTALLCOMMAND dialog
  $TERMCOMMAND $INSTALLCOMMAND zenity
else
  if [[ $HASOVERLAYFS == 0 ]]
  then
    $INSTALLCOMMAND unionfs-fuse
  fi
  $INSTALLCOMMAND squashfs-tools
  $INSTALLCOMMAND dialog
  $INSTALLCOMMAND zenity
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

#mount the ISO
mount -o loop "$MOUNTISO" "$MOUNTHOME"/liveisotest/isomount


#if the iso doesn't have a squashfs image
if [ ! -f "$MOUNTHOME"/liveisotest/isomount/casper/filesystem.squashfs  ]
then
  if [[ $XALIVE == 0 ]]
  then
    zenity --info --text "Invalid CDROM image. Not an Ubuntu based image. Exiting and unmounting the image."
  else
    echo "Invalid CDROM image. Not an Ubuntu based image. Press enter."
    read a 
  fi
  #unmount and exit
  umount "$MOUNTHOME"/liveisotest/isomount
  exit
fi


#mount the squashfs image
mount -o loop "$MOUNTHOME"/liveisotest/isomount/casper/filesystem.squashfs "$MOUNTHOME"/liveisotest/squashfsmount

#Create the union between squashfs and the overlay
if [[ $HASOVERLAYFS == 0 ]]
then
  unionfs-fuse -o cow,use_ino,suid,dev,default_permissions,allow_other,nonempty,max_files=131068 "$MOUNTHOME"/liveisotest/overlay=RW:"$MOUNTHOME"/liveisotest/squashfsmount "$MOUNTHOME"/liveisotest/unionmountpoint
else
  mkdir -p "$MOUNTHOME"/liveisotest/unionwork
  mount -t overlay overlay -o lowerdir="$MOUNTHOME"/liveisotest/squashfsmount,upperdir="$MOUNTHOME"/liveisotest/overlay,workdir="$MOUNTHOME"/liveisotest/unionwork "$MOUNTHOME"/liveisotest/unionmountpoint
fi

#bind mount in the critical filesystems
mount --rbind /dev "$MOUNTHOME"/liveisotest/unionmountpoint/dev
mount --rbind /proc "$MOUNTHOME"/liveisotest/unionmountpoint/proc
mount --rbind /sys "$MOUNTHOME"/liveisotest/unionmountpoint/sys
mount --rbind /tmp "$MOUNTHOME"/liveisotest/unionmountpoint/tmp
mkdir -p "$MOUNTHOME"/liveisotest/unionmountpoint/run/shm
mount --rbind /run/shm "$MOUNTHOME"/liveisotest/unionmountpoint/run/shm
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

#Only configure the systemd if the online file doesn't exist so it is only configured once
if [[ ! -f "$MOUNTHOME"/liveisotest/unionmountpoint/online ]]
then
  #Configure test system
  mkdir -p  "$MOUNTHOME"/liveisotest/unionmountpoint/run/user/$SUDO_UID
  chmod 700 "$MOUNTHOME"/liveisotest/unionmountpoint/run/user/$SUDO_UID
  chown $SUDO_UID "$MOUNTHOME"/liveisotest/unionmountpoint/run/user/$SUDO_UID
  rm "$MOUNTHOME"/liveisotest/unionmountpoint/etc/resolv.conf
  cp /etc/resolv.conf "$MOUNTHOME"/liveisotest/unionmountpoint/etc
  chroot "$MOUNTHOME"/liveisotest/unionmountpoint groupadd -g $SUDO_UID livetest
  chroot "$MOUNTHOME"/liveisotest/unionmountpoint groupadd -r admin 
  chroot "$MOUNTHOME"/liveisotest/unionmountpoint /usr/sbin/useradd -g livetest -m -p $(cat /etc/shadow|grep ^$SUDO_USER: | awk -F : '{print $2}') -s /bin/bash -G admin,plugdev -u $SUDO_UID livetest 
  mkdir -p "$MOUNTHOME"/liveisotest/unionmountpoint/var/run/dbus
  chroot "$MOUNTHOME"/liveisotest/unionmountpoint dbus-daemon --system --fork
  chroot "$MOUNTHOME"/liveisotest/unionmountpoint upower &
  #give more information in the testuser .bashrc
  echo "
echo \"
Weston Session commands:
nested-defaultweston-caller
nested-hawaii-caller
nested-orbital-caller
nested-enlightenment-caller
nested-gnomeshell-caller
nested-kdeplasma-caller

NOTE: Any commands entered in this tab will effect the mounted system.
If this terminal program that is running in this window supports tabs, any new tabs will be running as root to your real system.
Exercise caution. Even some paticular commands run in here can effect your real system.\"" >> "$MOUNTHOME"/liveisotest/unionmountpoint/home/livetest/.bashrc
  echo 'cd $(eval echo ~$LOGNAME)' >> "$MOUNTHOME"/liveisotest/unionmountpoint/home/livetest/.bashrc

  touch "$MOUNTHOME"/liveisotest/unionmountpoint/online
fi

if [[ $XALIVE == 0 ]]
then
  $TERMCOMMAND chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
else
  chroot "$MOUNTHOME"/liveisotest/unionmountpoint su livetest
fi

#go back to the users home folder
cd "$MOUNTHOME"


mountisoexit
