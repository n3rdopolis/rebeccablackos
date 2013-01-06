#! /bin/bash
#    Copyright (c) 2012, nerdopolis (or n3rdopolis) <bluescreen_avenger@version.net>
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

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#Create the correct /etc/resolv.conf symlink
ln -s ../run/resolvconf/resolv.conf /etc/resolv.conf 

#update the apt cache
apt-get update

#install remastersys key
wget -O - http://www.remastersys.com/ubuntu/remastersys.gpg.key | apt-key add -

#install basic applications that the system needs to get repositories
yes Y| apt-get install aptitude git bzr subversion

#create folder for install logs
mkdir -p /usr/share/logs/package_operations

#clean up possible older logs
rm /usr/share/logs/package_operations/*

#LIST OF PACKAGES TO GET INSTALLED
INSTALLS="$(cat /tmp/INSTALLS.txt | awk -F "#" '{print $1}')"

#DOWNLOAD THE PACKAGES SPECIFIED
echo "$INSTALLS" | while read PACKAGEINSTRUCTION
do
PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

if [[ $METHOD == "PART" ]]
then
echo "Downloading with partial dependancies for $PACKAGE"                       |tee -a /usr/share/logs/package_operations/Downloads
yes Yes | apt-get --no-install-recommends install $PACKAGE -d -y --force-yes    |tee -a /usr/share/logs/package_operations/Downloads
elif [[ $METHOD == "FULL" ]]
then
echo "Downloading with all dependancies for $PACKAGE"                           |tee -a /usr/share/logs/package_operations/Downloads
yes Yes | apt-get install $PACKAGE -d -y --force-yes                            |tee -a /usr/share/logs/package_operations/Downloads
elif [[ $METHOD == "BUILDDEP" ]]
then
echo "Downloading build dependancies for $PACKAGE"                              |tee -a /usr/share/logs/package_operations/Downloads
yes Y | apt-get build-dep $PACKAGE -d -y --force-yes                            |tee -a /usr/share/logs/package_operations/Downloads 
else
echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   |tee -a /usr/share/logs/package_operations/Downloads
fi

done

#Download updates
yes Y | apt-get dist-upgrade -d -y --force-yes

#create the folder for ccache
mkdir -p /srcbuild/.ccache

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only