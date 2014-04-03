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


#Redirect these utilitues to /bin/true during the live CD Build process. They aren't needed and cause package installs to complain
dpkg-divert --local --rename --remove /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /sbin/initctl
dpkg-divert --local --rename --remove /usr/sbin/invoke-rc.d
rm /sbin/initctl.distrib
rm /usr/sbin/grub-probe.distrib
rm /usr/sbin/invoke-rc.d.distrib
dpkg-divert --local --rename --add /usr/sbin/grub-probe
dpkg-divert --local --rename --add /sbin/initctl
dpkg-divert --local --rename --add /usr/sbin/invoke-rc.d
ln -s /bin/true /sbin/initctl
ln -s /bin/true /usr/sbin/grub-probe
ln -s /bin/true /usr/sbin/invoke-rc.d

#Create dpkg config file to speed up install operations for the ISO build. It gets removed once done. 
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/force-unsafe-io

#perl outputs complaints if a locale isn't generated
sudo locale-gen en_US.UTF-8

#Create the correct /etc/resolv.conf symlink
ln -s ../run/resolvconf/resolv.conf /etc/resolv.conf 

#update the apt cache
apt-get update

#install basic applications that the system needs to get repositories and packages
apt-get install aptitude git bzr subversion mercurial wget dselect -y --force-yes 

#update the dselect database
yes Y | dselect update

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#clean up possible older logs
rm -r /usr/share/logs/package_operations/Installs

#Create folder to hold the install logs
mkdir -p /usr/share/logs/package_operations/Installs

#Get the packages that need to be installed, by determining new packages specified, and packages that did not complete.
sed -i 's/^ *//;s/ *$//' /tmp/FAILEDREMOVES.txt
sed -i 's/^ *//;s/ *$//' /tmp/FAILEDINSTALLS.txt
sed -i 's/^ *//;s/ *$//' /tmp/INSTALLS.txt
sed -i 's/^ *//;s/ *$//' /tmp/INSTALLS.txt.installbak
touch /tmp/FAILEDINSTALLS.txt
diff -u -N -w1000 /tmp/INSTALLS.txt.installbak /tmp/INSTALLS.txt | grep -v ::BUILDDEP | grep -v ::REMOVE | grep ^- | grep -v "\---" | cut -c 2- | awk -F "#" '{print $1}' >> /tmp/FAILEDREMOVES.txt
INSTALLS=$(diff -u -N -w1000 /tmp/FAILEDREMOVES.txt /tmp/INSTALLS.txt | grep ^- | grep -v "\---" | cut -c 2- | awk -F :: '{print $1"::REMOVE"}')
INSTALLS+="
$(diff -u -N -w1000 /tmp/INSTALLS.txt.installbak /tmp/INSTALLS.txt | grep ^+ | grep -v +++ | cut -c 2- | awk -F "#" '{print $1}' | tee -a /tmp/FAILEDINSTALLS.txt )"
INSTALLS+="
$(diff -u10000 -w1000 -N /tmp/INSTALLS.txt /tmp/FAILEDINSTALLS.txt | grep "^ " | cut -c 2- )"
INSTALLS="$(echo "$INSTALLS" | awk ' !x[$0]++')"


#DOWNLOAD THE PACKAGES SPECIFIED
while read PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

  #This is for partial installs
  if [[ $METHOD == "PART" ]]
  then
    echo "Installing with partial dependancies for $PACKAGE"                        2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    apt-get --no-install-recommends install $PACKAGE -y --force-yes       2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[1]}
  #This is for full installs
  elif [[ $METHOD == "FULL" ]]
  then
    echo "Installing with all dependancies for $PACKAGE"                            2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    apt-get install $PACKAGE -y --force-yes                               2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[1]}
  #this is for build dependancies
  elif [[ $METHOD == "BUILDDEP" ]]
  then
    echo "Installing build dependancies for $PACKAGE"                               2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    apt-get build-dep $PACKAGE -y --force-yes                               2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[1]}
  #Remove packages if specified, or if a package is no longer specified in INSTALLS.txt
  elif [[ $METHOD == "REMOVE" ]]
  then
    echo "Removing $PACKAGE"                                                       	2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    apt-get purge $PACKAGE -y --force-yes                                  	2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    Result=${PIPESTATUS[1]}
  else
    echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   2>&1 |tee -a /usr/share/logs/package_operations/Installs/"$PACKAGE".log
    Result=1
  fi

  #if the install resut for the current package failed, then log it. If it worked, then remove it from the list of unfinished installs
  if [[ $Result != 0 ]]
  then
    echo "$PACKAGE failed to $METHOD" |tee -a /usr/share/logs/package_operations/Installs/failedpackages.log
  else
    echo "$PACKAGE successfully $METHOD"
    grep -v "$PACKAGEINSTRUCTION" /tmp/FAILEDINSTALLS.txt > /tmp/FAILEDINSTALLS.txt.bak
    cat /tmp/FAILEDINSTALLS.txt.bak > /tmp/FAILEDINSTALLS.txt
    rm /tmp/FAILEDINSTALLS.txt.bak
    if [[ $METHOD == "REMOVE" ]]
    then
      grep -v "$PACKAGEINSTRUCTION" /tmp/FAILEDREMOVES.txt > /tmp/FAILEDREMOVES.txt.bak
      cat /tmp/FAILEDREMOVES.txt.bak > /tmp/FAILEDREMOVES.txt
      rm /tmp/FAILEDREMOVES.txt.bak
    fi

  fi

done < <(echo "$INSTALLS")

cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.installbak

zz
#remove old kernels!
CURRENTKERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3}')
if [[ -z $CURRENTKERNELVERSION ]]
then
  CURRENTKERNELVERSION=$(dpkg --get-selections | awk '{print $1}' | grep linux-image-[0-9] | tail -1 |awk -F "-" '{print $3"-"$4}')
fi

dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELVERSION" | grep 'linux-image\|linux-headers' | grep -v linux-image-generic | grep -v linux-headers-generic | while read PACKAGE
do
  apt-get purge $PACKAGE -y --force-yes 
done

#install updates
apt-get dist-upgrade -y --force-yes					2>&1 |tee -a /usr/share/logs/package_operations/Installs/dist-upgrade.log

#Delete the old depends of the packages no longer needed.
apt-get --purge autoremove -y 						2>&1 |tee -a /usr/share/logs/package_operations/Installs/purge.log

#Reset the utilites back to the way they are supposed to be.
rm /sbin/initctl
rm /usr/sbin/grub-probe
rm /usr/sbin/invoke-rc.d
dpkg-divert --local --rename --remove /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /sbin/initctl
dpkg-divert --local --rename --remove /usr/sbin/invoke-rc.d

#delete the dpkg config file that speeds up the installs, so the user doesn't get it.
rm /etc/dpkg/dpkg.cfg.d/force-unsafe-io

#Capture the packages that are installed and not installed.
dpkg --get-selections > /tmp/INSTALLSSTATUS.txt
