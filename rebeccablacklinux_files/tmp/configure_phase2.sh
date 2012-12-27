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

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#install aptitude
yes Y| apt-get install aptitude

#LIST OF PACKAGES TO GET INSTALLED
BINARYINSTALLS="$(cat /tmp/BINARYINSTALLS.txt | awk -F "#" '{print $1}')"

#LIST OF PACKAGES THAT NEED BUILD DEPS
BUILDINSTALLS="$(cat /tmp/BUILDINSTALLS.txt | awk -F "#" '{print $1}')"


#INSTALL THE PACKAGES SPECIFIED
echo "$BINARYINSTALLS" | while read PACKAGEINSTRUCTION
do
PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F ":" '{print $1}' )
METHOD=$(echo $PACKAGEINSTRUCTION | awk -F ":" '{print $2}' )

if [[ $METHOD == "PART" ]]
then
yes Yes | apt-get --no-install-recommends install $PACKAGE -y --force-yes
else
yes Yes | apt-get install $PACKAGE -y --force-yes
fi

done


#GET BUILDDEPS FOR THE PACKAGES SPECIFIED
echo "$BUILDINSTALLS" | while read PACKAGE
do
yes Y | apt-get build-dep $PACKAGE -y --force-yes
done


#remove old kernels!
CURRENTKERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3}')
dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELVERSION" | grep linux-image | grep -v linux-image-generic | while read PACKAGE
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

#delete the downloaded file cache
apt-get clean


# /lib/plymouth/ubuntu-logo.png
echo FRAMEBUFFER=y > /etc/initramfs-tools/conf.d/splash


#copy all the post install files
rsync /usr/import/* -a /

#delete the import folder
rm -r /usr/import

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Edit remastersys to not detect the filesystem. df fails in chroot
sed  -i 's/^DIRTYPE=.*/DIRTYPE=ext4/' /usr/bin/remastersys

#get the installed kernel version in /lib/modules, there is only one installed in this CD, but take the first one by default.
KERNELVERSION=$(ls /lib/modules/ | head -1 )

#This is a kde distro. Force the remastersys script to install kde frontend, as Remastersys detects running process from kde to determine it is a kde distro, but since this is chroot, it's not running
sed -i "s/\"\`ps axf | grep startkde | grep -v grep\`\" != \"\" -o \"\`ps axf | grep kwin | grep -v grep\`\" != \"\"/ 1 /g" /usr/bin/remastersys


#replace all of remastersys's unames with the installed kernel version.
sed -i "s/\`uname -r\`/$KERNELVERSION/g" /usr/bin/remastersys

#make remastersys use xz compression
sed -i 's/SQUASHFSOPTS="/SQUASHFSOPTS="-comp xz/g' /usr/bin/remastersys

#Don't allow remastersys to remove ubiquity!!!
grep -v "remove ubiquity" /usr/bin/remastersys > /usr/bin/remastersys.bak
cat /usr/bin/remastersys.bak > /usr/bin/remastersys
rm /usr/bin/remastersys.bak

#remove the resolv.conf from the list of files in /etc that remastersys deletes, as it's a symlink to a dynamic file. 
sed -i 's/resolv.conf,//g'  /usr/bin/remastersys

#save the build date of the CD.
echo "$(date)" > /etc/builddate



#install the menu items for the wayland tests
install_menu_items

#set a variable for remastersys to exclude srcbuild
export EXCLUDES=/srcbuild

#start the remastersys job
remastersys dist

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso

#uninstall cmake
make -C /srcbuild/cmake uninstall

#This will remove my abilities to build packages from the ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)

yes Y | apt-get purge $REMOVEDEVPGKS


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS


REMOVEDEVPGKS="texlive-base ubuntu-docs gnome-user-guide subversion git bzr cmake libgl1-mesa-dri-dbg libglib2.0-doc"
yes Y | apt-get purge $REMOVEDEVPGKS


yes Y | apt-get autoremove

#hide buildlogs in tmp from remastersys
mv /usr/share/Buildlog     /tmp
mv /usr/share/Downloadlog /tmp

#delete headers (some software leaks headers to /usr/include)
rm -rf /opt/include
rm -rf /usr/include

#delete bloated binary files that are for development, and are not needed on the smaller iso
rm /opt/bin/Xnest
rm /opt/bin/Xvfb
rm /opt/bin/rcc
rm /opt/bin/moc
rm /opt/bin/qdbusxml2cpp
rm /opt/bin/qmake
rm /opt/bin/ctest
rm /opt/bin/cpack
rm /opt/bin/ccmake
rm /opt/bin/cmake
rm /opt/bin/qdoc
rm /opt/bin/uic
rm /opt/bin/qdbuscpp2xml


#remove duplicated samples
rm -rf /opt/examples

#clean more apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
rm -rf /var/lib/apt/lists/*

#start the remastersys job
remastersys dist

#move logs back
mv /tmp/Buildlog /usr/share
mv /tmp/Downloadlog /usr/share


