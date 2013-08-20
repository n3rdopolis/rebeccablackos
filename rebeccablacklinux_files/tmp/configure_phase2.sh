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


#Redirect these utilitues to /bin/true during the live CD Build process. They aren't needed and cause package installs to complain
dpkg-divert --local --rename --add /usr/sbin/grub-probe
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
ln -s /bin/true /usr/sbin/grub-probe

#Create dpkg config file to speed up install operations for the ISO build. It gets removed once done. 
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/force-unsafe-io

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#install aptitude
yes Y| apt-get install aptitude

#clean up possible older logs
rm -r /usr/share/logs/package_operations/Installs

#Create folder to hold the install logs
mkdir /usr/share/logs/package_operations/Installs

#LIST OF PACKAGES TO GET INSTALLED
INSTALLS="$(diff -uN /tmp/INSTALLS.txt.bak /tmp/INSTALLS.txt | grep -v ::BUILDDEP | grep ^- | grep -v "\---" | cut -d - -f2- | awk -F "#" '{print $1}' | awk -F :: '{print $1"::REMOVE"}')"
INSTALLS+="
$(diff -uN /tmp/INSTALLS.txt.bak /tmp/INSTALLS.txt | grep ^+ | grep -v +++ | awk -F + '{print $2}' | awk -F "#" '{print $1}')"

#Archive this current list of installs.
cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.bak

#DOWNLOAD THE PACKAGES SPECIFIED
echo "$INSTALLS" | while read PACKAGEINSTRUCTION
do
PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

if [[ $METHOD == "PART" ]]
then
echo "Installing with partial dependancies for $PACKAGE"                        |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
yes Yes | apt-get --no-install-recommends install $PACKAGE -y --force-yes       |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
elif [[ $METHOD == "FULL" ]]
then
echo "Installing with all dependancies for $PACKAGE"                            |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
yes Yes | apt-get install $PACKAGE -y --force-yes                               |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
elif [[ $METHOD == "BUILDDEP" ]]
then
echo "Installing build dependancies for $PACKAGE"                               |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
yes Y | apt-get build-dep $PACKAGE -y --force-yes                               |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
elif [[ $METHOD == "REMOVE" ]]
then
echo "Removing $PACKAGE"                                                        |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
yes Y | apt-get purge $PACKAGE -y --force-yes                                   |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
else
echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
fi

done


#remove old kernels!
CURRENTKERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3}')
if [[ -z $CURRENTKERNELVERSION ]]
then
CURRENTKERNELVERSION=$(dpkg --get-selections | awk '{print $1}' | grep linux-image-[0-9] | tail -1 |awk -F "-" '{print $3"-"$4}')
fi

dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELVERSION" | grep 'linux-image\|linux-headers' | grep -v linux-image-generic | grep -v linux-headers-generic | while read PACKAGE
do
yes Y | apt-get purge $PACKAGE
done

#install updates
yes Y | apt-get dist-upgrade -y --force-yes

#Delete the old depends of the packages no longer needed.
yes Y | apt-get --purge autoremove -y 

#Reset the utilites back to the way they are supposed to be.
rm /sbin/initctl
rm /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /sbin/initctl

#delete the dpkg config file that speeds up the installs, so the user doesn't get it.
rm /etc/dpkg/dpkg.cfg.d/force-unsafe-io

#delete the downloaded file cache
apt-get clean
