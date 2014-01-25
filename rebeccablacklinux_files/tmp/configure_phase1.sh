#! /bin/bash
#    Copyright (c) 2012, 2013, 2014 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
#
#    This file is part of RebeccaBlackLinux.
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

#perl outputs complaints if a locale isn't generated
sudo locale-gen en_US.UTF-8

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#Create the correct /etc/resolv.conf symlink
ln -s ../run/resolvconf/resolv.conf /etc/resolv.conf 

#update the apt cache
apt-get update

#install basic applications that the system needs to get repositories and packages
yes Y| apt-get install aptitude git bzr subversion mercurial wget dselect

#update the dselect database
dselect update

#create folder for install logs
mkdir -p /usr/share/logs/package_operations

#clean up possible older logs
rm -r /usr/share/logs/package_operations/Downloads

#Create folder to hold the install logs
mkdir /usr/share/logs/package_operations/Downloads

#LIST OF PACKAGES TO GET INSTALLED
sed -i 's/^ *//;s/ *$//' /tmp/FAILEDDOWNLOADS.txt
sed -i 's/^ *//;s/ *$//' /tmp/INSTALLS.txt
sed -i 's/^ *//;s/ *$//' /tmp/INSTALLS.txt.downloadbak
touch /tmp/FAILEDDOWNLOADS.txt
INSTALLS="$(diff -u -N -w1000 /tmp/INSTALLS.txt.downloadbak /tmp/INSTALLS.txt | grep ^+ | grep -v +++ | cut -c 2- | awk -F "#" '{print $1}' | tee -a /tmp/FAILEDDOWNLOADS.txt )"
INSTALLS+="$(echo; diff -u10000 -w1000 -N /tmp/INSTALLS.txt /tmp/FAILEDDOWNLOADS.txt | grep "^ " | cut -c 2- )"
INSTALLS="$(echo "$INSTALLS" | awk ' !x[$0]++')"

#DOWNLOAD THE PACKAGES SPECIFIED
while read PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

  if [[ $METHOD == "PART" ]]
  then
    echo "Downloading with partial dependancies for $PACKAGE"                       2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    yes Yes | apt-get --no-install-recommends install $PACKAGE -d -y --force-yes    2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    Result=${PIPESTATUS[1]}
  elif [[ $METHOD == "FULL" ]]
  then
    echo "Downloading with all dependancies for $PACKAGE"                           2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    yes Yes | apt-get install $PACKAGE -d -y --force-yes                            2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    Result=${PIPESTATUS[1]}
  elif [[ $METHOD == "BUILDDEP" ]]
  then
    echo "Downloading build dependancies for $PACKAGE"                              2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    yes Y | apt-get build-dep $PACKAGE -d -y --force-yes                            2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log 
    Result=${PIPESTATUS[1]}
  else
    echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
  Result=1
  fi

  if [[ $Result != 0 ]]
  then
    echo "$PACKAGE failed to $METHOD" |tee -a /usr/share/logs/package_operations/Downloads/failedpackages.log
  else
    echo "$PACKAGE successfully $METHOD"
    grep -v "$PACKAGEINSTRUCTION" /tmp/FAILEDDOWNLOADS.txt > /tmp/FAILEDDOWNLOADS.txt.bak
    cat /tmp/FAILEDDOWNLOADS.txt.bak > /tmp/FAILEDDOWNLOADS.txt
    rm /tmp/FAILEDDOWNLOADS.txt.bak
  fi
done < <(echo "$INSTALLS")

cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.downloadbak

#Download updates
yes Y | apt-get dist-upgrade -d -y --force-yes					2>&1 |tee -a /usr/share/logs/package_operations/Downloads/dist-upgrade.log
    
#Use dselect-upgrade in download only mode to force the downloads of the cached and uninstalled debs in phase 1
dpkg --get-selections > /tmp/DOWNLOADSSTATUS.txt
dpkg --set-selections < /tmp/INSTALLSSTATUS.txt
echo Y | apt-get -d -u dselect-upgrade --no-install-recommends			2>&1 |tee -a /usr/share/logs/package_operations/Downloads/dselect-upgrade.log
dpkg --clear-selections
dpkg --set-selections < /tmp/DOWNLOADSSTATUS.txt

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only