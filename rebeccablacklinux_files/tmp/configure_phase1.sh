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

#update the apt cache
apt-get update

#install remastersys key
wget -O - http://www.remastersys.com/ubuntu/remastersys.gpg.key | apt-key add -

#LIST OF PACKAGES TO GET INSTALLED
BINARYINSTALLS="aptitude
apt-rdepends
libsqlite3-dev
language-pack-en 
linux-generic
llvm
libxkbcommon-dev
manpages
build-essential 
libtool 
libxi-dev 
libxmu-dev 
libxt-dev 
bison flex 
libgl1-mesa-dev 
xutils-dev 
libtalloc-dev 
libdrm-dev 
autoconf 
x11proto-kb-dev 
libegl1-mesa-dev 
libgles2-mesa-dev 
libgdk-pixbuf2.0-dev 
libudev-dev 
libxcb-dri2-0-dev
libxcb-xfixes0 
libxcb-xfixes0-dev 
shtool 
libffi-dev 
libpoppler-glib-dev 
libgtk2.0-dev 
git diffstat 
libx11-xcb-dev 
quilt 
autopoint 
dh-autoreconf 
xkb-data 
gtk-doc-tools 
gobject-introspection 
gperf 
librsvg2-bin 
libpciaccess-dev  
python-libxml2 
libjpeg-dev   
libvpx-dev
libgbm-dev 
libxcb-glx0-dev 
libgl1-mesa-dri-dbg
ubuntu-standard
lightdm
kde-plasma-desktop
plasma-widget-networkmanagement
plymouth-theme-kubuntu-logo
plymouth-theme-kubuntu-text
xcursor-themes
nouveau-firmware
firefox 
gedit 
file-roller 
clutter-1.0-tests
ncurses-dev
libmtdev-dev
libxcb1 
libxcb1-dev 
libx11-xcb1 
libx11-xcb-dev 
libxcb-keysyms1 
libxcb-keysyms1-dev 
libxcb-image0 
libxcb-image0-dev 
libxcb-shm0 
libxcb-shm0-dev 
libxcb-icccm4 
libxcb-icccm4-dev 
libxcb-sync0 
libxcb-sync0-dev 
libxcb-xfixes0-dev 
libgtk-3-dev 
libgio2.0-cil-dev 
libjson-glib-dev
x11proto-xcmisc-dev   
x11proto-bigreqs-dev 
x11proto-fonts-dev  
x11proto-video-dev 
x11proto-record-dev 
x11proto-resource-dev 
libxkbfile-dev 
libxfont-dev 
xserver-xorg-dev 
x11proto-xf86dri-dev 
subversion 
subversion-tools
e17
libicu-dev 
libraptor-dev
remastersys
ubuntu-minimal
xterm
vpx-tools
libkactivities-dev
libqimageblitz-dev
kde-workspace-dev
ubiquity-frontend-kde"

#LIST OF PACKAGES THAT NEED BUILD DEPS
BUILDINSTALLS="libgtk-3-0 
libgtk2.0-0
libclutter-1.0-0
mesa
tinc
e17  
kde4libs
kde-baseapps
kde-workspace"

#LIST OF PACKAGES TO REMOVE
UNINSTALLS="" 

#INSTALL THE PACKAGES SPECIFIED
echo "$BINARYINSTALLS" | while read PACKAGE
do
yes Y | apt-get install $PACKAGE -y --force-yes
done


#GET BUILDDEPS FOR THE PACKAGES SPECIFIED
echo "$BUILDINSTALLS" | while read PACKAGE
do
yes Y | apt-get build-dep $PACKAGE -y --force-yes
done

##################################################################################################################




#For some reason, it installs out of date packages sometimes, as I see unupgraded packages
yes Y | apt-get dist-upgrade 

#remove old kernels!
CURRENTKERNELPACKAGES=$(apt-rdepends linux-image-generic | grep linux-image | sed 's/  Depends: //g' | sort | uniq)
dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELPACKAGES" | grep linux-image | while read PACKAGE
do
yes Y | apt-get purge $PACKAGE
done

#remove uneeded packages
echo "$UNINSTALLS" | while read PACKAGE
do
yes Y | apt-get --purge remove $PACKAGE -y
done


#Delete the old depends of the packages no longer needed.
yes Y | apt-get --purge autoremove -y 

#Reset the utilites back to the way they are supposed to be.
rm /sbin/initctl
rm /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /sbin/initctl

#delete the downloaded file cache
apt-get clean

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only