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

#Require root privlages
if [[ $UID != 0 ]]
then
  echo "Must be run as root."
  exit
fi

export PACKAGEOPERATIONLOGDIR=/buildlogs/package_operations

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

#install basic applications that the system needs to get repositories and packages
apt-get install aptitude git bzr subversion mercurial wget rustc curl dselect locales acl sudo -y 

#perl outputs complaints if a locale isn't generated
locale-gen en_US.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#Create folder to hold the install logs
mkdir -p "$PACKAGEOPERATIONLOGDIR"/Installs

#Ensure that the files that are being created exist
touch /tmp/FAILEDREMOVES.txt
touch /tmp/FAILEDINSTALLS.txt
touch /tmp/INSTALLS.txt.installbak

#Get the packages that need to be installed, by determining new packages specified, and packages that did not complete.
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/FAILEDREMOVES.txt
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/FAILEDINSTALLS.txt
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/INSTALLS.txt.installbak

#Get the list of packages to remove, that have been removed from INSTALLS_LIST.txt
grep -Fxv -f /tmp/INSTALLS.txt /tmp/INSTALLS.txt.installbak | grep -v ::REMOVE | awk -F "#" '{print $1}' >> /tmp/FAILEDREMOVES.txt

#Ensure that all the failed removes that will attempt to be removes again are not actually specified to be installed again in INSTALLS_LIST.txt
INSTALLS=$(grep -Fxv -f /tmp/INSTALLS.txt /tmp/FAILEDREMOVES.txt | awk -F :: '{print $1"::REMOVE"}')

#Get list of new packages to install, compared from the previous run
INSTALLS+=$'\n'
INSTALLS_FAILAPPEND="$(grep -Fxv -f /tmp/INSTALLS.txt.installbak /tmp/INSTALLS.txt | awk -F "#" '{print $1}' )"
INSTALLS+=$INSTALLS_FAILAPPEND

#Add the FAILEDINSTALLS.txt contents to the installs list, insure that the failed package is still set to be installed by INSTALLS_LIST.txt
INSTALLS+="
$(grep -Fx -f /tmp/INSTALLS.txt /tmp/FAILEDINSTALLS.txt )"

#log new packages to FAILEDINSTALLS.txt, which will then be removed once the download is successful
echo "$INSTALLS_FAILAPPEND" >> /tmp/FAILEDINSTALLS.txt

#Clear any empty lines
INSTALLS=$(echo -n "$INSTALLS" |sed 's/^ *//;s/ *$//;/^::$/d;/^$/d')

#Add a newline, only if there is one or more actual lines
if [[ ! -z $INSTALLS ]]
then
  INSTALLS+=$'\n'
fi

#DOWNLOAD THE PACKAGES SPECIFIED
while read PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

  #This is for partial installs
  if [[ $METHOD == "PART" ]]
  then
    echo "Installing with partial dependancies for $PACKAGE"                        2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    apt-get --no-install-recommends install $PACKAGE -y       2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
  #This is for full installs
  elif [[ $METHOD == "FULL" ]]
  then
    echo "Installing with all dependancies for $PACKAGE"                            2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    apt-get install $PACKAGE -y                                         2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
  #Remove packages if specified, or if a package is no longer specified in INSTALLS.txt
  elif [[ $METHOD == "REMOVE" ]]
  then
    echo "Removing $PACKAGE"                                                               2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    apt-get purge $PACKAGE -y                                 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
    if [[ $Result != 0 ]]
    then
      dpkg -l $PACKAGE &> /dev/null
      if [[ $? != 0 ]]
      then
         Result=0
      fi
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
  else
    echo "$PACKAGE successfully $METHOD"
    grep -v "$PACKAGEINSTRUCTION" /tmp/FAILEDINSTALLS.txt > /tmp/FAILEDINSTALLS.txt.bak
    cat /tmp/FAILEDINSTALLS.txt.bak > /tmp/FAILEDINSTALLS.txt
    rm /tmp/FAILEDINSTALLS.txt.bak
    if [[ $METHOD == "REMOVE" ]]
    then
      grep -v "$PACKAGE::" /tmp/FAILEDREMOVES.txt > /tmp/FAILEDREMOVES.txt.bak
      cat /tmp/FAILEDREMOVES.txt.bak > /tmp/FAILEDREMOVES.txt
      rm /tmp/FAILEDREMOVES.txt.bak
    fi

  fi

done < <(echo -n "$INSTALLS")

cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.installbak


#remove old kernels!
CURRENTKERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3}')
if [[ -z $CURRENTKERNELVERSION ]]
then
  CURRENTKERNELVERSION=$(dpkg --get-selections | awk '{print $1}' | grep linux-image-[0-9]'\.'[0-9] | tail -1 |awk -F "-" '{print $3"-"$4}')
fi

dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELVERSION" | grep 'linux-image\|linux-headers' | grep -E \(linux-image-[0-9]'\.'[0-9]\|linux-headers-[0-9]'\.'[0-9]\) | while read PACKAGE
do
  apt-get purge $PACKAGE -y 
done

#install updates
apt-get dist-upgrade -y                                                 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/dist-upgrade.log

#Delete the old depends of the packages no longer needed.
apt-get --purge autoremove -y                                           2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/purge_autoremove.log

#prevent packages removed from the repositories upstream to not make it in the ISOS
ESSENTIALOBSOLETEPACKAGECOUNT=$(aptitude search '~o~E' |wc -l)
if [[ $ESSENTIALOBSOLETEPACKAGECOUNT == 0 ]]
then
  aptitude purge ?obsolete -y                                          2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/purge_obsolete.log
else
  echo        "Not purging older packages, because apt-get update failed"    2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Installs/purge_obsolete.log
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
