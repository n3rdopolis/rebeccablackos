#! /bin/bash
#    Copyright (c) 2012 - 2023 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#Require root privlages
if [[ $UID != 0 ]]
then
  echo "Must be run as root."
  exit
fi

function SymlinkDirToDir
{
  SourceDir="$1"
  DestinationDir="$2"
  FileSuffix="$3"
  mkdir -p "$SourceDir"
  mkdir -p "$DestinationDir"
  env -C "$SourceDir" -- find -printf '%P\n' | sort | while read -r Item
  do
    if [[ -d "$SourceDir/$Item" ]]
    then
      if [[ ! -e "$DestinationDir/$Item" ]]
      then
        mkdir -p "$DestinationDir/$Item"
      fi
    else
      if [[ ! -e "$DestinationDir/$Item" ]]
      then
        if [[ -z $FileSuffix ]]
        then
          ln -s "$SourceDir/$Item" "$DestinationDir/$Item"
        else
          FolderLeaf=$(dirname "$Item")
          FileName=${Item##*/}
          IFS="."
          FileName=($FileName)
          ElementCount=${#FileName[@]}
          if [[ $ElementCount -gt 2 ]]
          then
            IndexNumber=$(( $ElementCount - 2 ))
          else
            IndexNumber=0
          fi
          FileName[$IndexNumber]="${FileName[$IndexNumber]}-$FileSuffix"
          FileName=$(echo "${FileName[*]}")
          unset IFS
          mkdir -p "$DestinationDir/$FolderLeaf"
          ln -s "$SourceDir/$Item" "$DestinationDir/$FolderLeaf/$FileName"
        fi
      fi
    fi
  done
}

SymlinkDirToDir /opt/lib/udev/rules.d /usr/lib/udev/rules.d "rbos"

SymlinkDirToDir /opt/etc/pam.d /etc/pam.d "rbos"

SymlinkDirToDir /opt/lib/systemd/user /usr/lib/systemd/user/ ""

SymlinkDirToDir /opt/lib/systemd/system /usr/lib/systemd/system/ ""

SymlinkDirToDir /opt/share/polkit-1/actions /usr/share/polkit-1/actions/ "rbos"

SymlinkDirToDir /opt/share/polkit-1/rules.d /usr/share/polkit-1/rules.d/ "rbos"


SymlinkDirToDir /opt/etc/dbus-1/system.d /etc/dbus-1/system.d/ "rbos"
SymlinkDirToDir /opt/etc/dbus-1/services /etc/dbus-1/services/ "rbos"

SymlinkDirToDir /opt/share/dbus-1/system-services /usr/share/dbus-1/system-services/ "rbos"
SymlinkDirToDir /opt/share/dbus-1/system.d /usr/share/dbus-1/system.d/ "rbos"
