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

export PACKAGEOPERATIONLOGDIR=/var/log/buildlogs/package_operations

#function to handle moving back dpkg redirect files for chroot
function RevertFile {
  TargetFile=$1
  SourceFile=$(dpkg-divert --truename "$1")
  if [[ "$TargetFile" != "$SourceFile" ]]
  then
    rm "$1"
    dpkg-divert --local --rename --remove "$1"
  fi
}

#function to handle temporarily moving files with dpkg that attempt to cause issues with chroot
function RedirectFile {
  RevertFile "$1"
  dpkg-divert --local --rename --add "$1" 
  ln -s /bin/true "$1"
}

#Redirect these utilitues to /bin/true during the live CD Build process. They aren't needed and cause package installs to complain
RedirectFile /usr/sbin/grub-probe
RedirectFile /sbin/initctl
RedirectFile /usr/sbin/invoke-rc.d

#Configure dpkg
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/force-unsafe-io
echo "force-confold"   > /etc/dpkg/dpkg.cfg.d/force-confold
echo "force-confdef"   > /etc/dpkg/dpkg.cfg.d/force-confdef

#Create _apt user that apt drops to to run things as non-root
adduser --no-create-home --disabled-password --system --force-badname _apt

#Attempt to repair the dpkg state if it was stopped
apt-get install -f
dpkg --configure -a

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#install basic applications that the system needs to get repositories and packages
apt-get install aptitude git bzr subversion mercurial wget python-is-python3 python3-distutils rustc curl dselect dnsutils locales acl sudo usrmerge -y

#perl outputs complaints if a locale isn't generated
locale-gen en_US.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

#Create folder to hold the install logs
mkdir -p "$PACKAGEOPERATIONLOGDIR"/Installs

#Ensure that the files that are being created exist
touch /tmp/INSTALLS.txt.lastrun

#Generate a list of all valid packages off the apt cache into a quickly parseable format, to test if a package name is valid.
apt-cache search . | awk '{print $1}' > /tmp/AVAILABLEPACKAGES.txt

#Get list of new packages to install
INSTALLS=$(cat /tmp/INSTALLS.txt | awk -F "#" '{print $1}')
INSTALLS+=$'\n'

#Get list of new packages to remove, compared from the previous run
grep -Fxv -f /tmp/INSTALLS.txt /tmp/INSTALLS.txt.lastrun | grep -v ::REMOVE | awk -F "#" '{print $1}' | awk -F "::" '{print $1}' | while read -r OLDPACKAGE
do
  AvailableCount=$(cat /tmp/AVAILABLEPACKAGES.txt | grep -c ^$OLDPACKAGE$)
  if [[ $AvailableCount != 0 ]]
  then
    echo "$OLDPACKAGE" >> /tmp/INSTALLS.txt.removes
  fi
done
if [[ -f /tmp/INSTALLS.txt.removes ]]
then
  INSTALLS+=$(cat /tmp/INSTALLS.txt.removes | sort | uniq | while read -r PACKAGE
  do
    AvailableCount=$(cat /tmp/AVAILABLEPACKAGES.txt | grep -c ^$PACKAGE$)
    if [[ $AvailableCount != 0 ]]
    then
      echo "$PACKAGE::REMOVE"
    fi
  done)
fi
INSTALLS+=$'\n'

#Clear any empty lines
INSTALLS=$(echo -n "$INSTALLS" |sed 's/^ *//;s/ *$//;/^::$/d;/^$/d')

#Add a newline, only if there is one or more actual lines
if [[ ! -z $INSTALLS ]]
then
  INSTALLS+=$'\n'
fi

#INSTALL THE PACKAGES SPECIFIED
PART_PACKAGES=""
FULL_PACKAGES=""
REMOVE_PACKAGES=""
while read -r PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

  AvailableCount=$(cat /tmp/AVAILABLEPACKAGES.txt | grep -c ^$PACKAGE$)
  if [[ $AvailableCount == 0 ]]
  then
    Result=1
  else
    Result=0
  fi

  #Partial install
  if [[ $METHOD == "PART" ]]
  then
    if [[ $Result == 0 ]]
    then
      echo "Installing with partial dependancies for $PACKAGE"                     > "$PACKAGEOPERATIONLOGDIR"/Installs/PART_Installs.log
      PART_PACKAGES+="$PACKAGE "
    fi
  #with all dependancies
  elif [[ $METHOD == "FULL" ]]
  then
    if [[ $Result == 0 ]]
    then
      echo "Installing with all dependancies for $PACKAGE"                         > "$PACKAGEOPERATIONLOGDIR"/Installs/FULL_Installs.log
      FULL_PACKAGES+="$PACKAGE "
    fi
  #Remove packages if specified, or if a package is no longer specified in INSTALLS.txt
  elif [[ $METHOD == "REMOVE" ]]
  then
    if [[ $Result == 0 ]]
    then
      echo "Removing $PACKAGE"                                                      > "$PACKAGEOPERATIONLOGDIR"/Installs/REMOVE_Uninstalls.log
      REMOVE_PACKAGES+="$PACKAGE "
    fi
  else
    echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    Result=1
    METHOD="INVALID OPERATION SPECIFIED"
  fi

  #if the install resut for the current package failed, then log it. If it worked, then remove it from the list of unfinished installs
  if [[ $Result != 0 ]]
  then
    echo "$PACKAGE failed to $METHOD" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
  fi

done < <(echo -n "$INSTALLS")

apt-get --no-install-recommends install $PART_PACKAGES -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/PART_Installs.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
  echo "Partial Installs failed: $PART_PACKAGES" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
fi

apt-get install $FULL_PACKAGES -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/FULL_Installs.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
  echo "Full Installs failed: $FULL_PACKAGES" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
fi

apt-get purge $REMOVE_PACKAGES -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/REMOVE_Uninstalls.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
  echo "Installs Removes failed: $REMOVE_PACKAGES" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
else
  rm /tmp/INSTALLS.txt.removes
fi


cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.lastrun

#install updates
apt-get dist-upgrade -y --no-install-recommends 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/dist-upgrade.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
 echo "APT dist-upgrade failed" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
fi

#remove old kernels!
if [[ -e /vmlinuz ]]
then
  CURRENTKERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3}')
  if [[ -z $CURRENTKERNELVERSION ]]
  then
    CURRENTKERNELVERSION=$(dpkg --get-selections | awk '{print $1}' | grep linux-image-[0-9]'\.'[0-9] | tail -1 |awk -F "-" '{print $3"-"$4}')
  fi

  dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELVERSION" | grep 'linux-image\|linux-headers' | grep -E \(linux-image-[0-9]'\.'[0-9]\|linux-headers-[0-9]'\.'[0-9]\) | while read -r PACKAGE
  do
    apt-get purge $PACKAGE -y
  done
fi

#Delete the old depends of the packages no longer needed.
apt-get --purge autoremove -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/purge_autoremove.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
 echo "APT autoremove failed" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
fi

#prevent packages removed from the repositories upstream to not make it in the ISOS
ESSENTIALOBSOLETEPACKAGECOUNT=$(aptitude search '~o~E' |wc -l)
if [[ $ESSENTIALOBSOLETEPACKAGECOUNT == 0 ]]
then
  aptitude purge ?obsolete -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/purge_obsolete.log
  Result=${PIPESTATUS[0]}
  if [[ $Result != 0 ]]
  then
   echo "APT purge failed" |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/failedpackages.log
  fi
else
  echo        "Not purging older packages, because apt-get update failed" 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/purge_obsolete.log
fi
#Reset the utilites back to the way they are supposed to be.
RevertFile /usr/sbin/grub-probe
RevertFile /sbin/initctl
RevertFile /usr/sbin/invoke-rc.d

#set dpkg to defaults
rm /etc/dpkg/dpkg.cfg.d/force-unsafe-io
rm /etc/dpkg/dpkg.cfg.d/force-confold
rm /etc/dpkg/dpkg.cfg.d/force-confdef

#Capture the packages that are installed and not installed.
dpkg --get-selections > /tmp/INSTALLSSTATUS.txt
