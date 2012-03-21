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


#mount the procfs
mount -t proc none /proc


#mount sysfs
mount -t sysfs none /sys



#mount /dev/pts
mount -t devpts none /dev/pts

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#update the apt cache
apt-get update

#LIST OF PACKAGES TO GET INSTALLED
BINARYINSTALLS="aptitude
language-pack-en 
linux-generic
llvm
libxkbcommon-dev
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
libgbm-dev 
libxcb-glx0-dev 
libgl1-mesa-dri-dbg
kubuntu-desktop 
ubuntu-standard 
firefox 
epiphany-browser 
evolution 
gedit 
gnibbles 
unity 
nautilus 
file-roller 
cheese
clutter-1.0-tests
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
e17
libraptor-dev
remastersys"

#LIST OF PACKAGES THAT NEED BUILD DEPS
BUILDINSTALLS="libgtk-3-0 
libgtk2.0-0
libclutter-1.0-0
mesa
tinc
e17  
kde4libs"

#INSTALL THE PACKAGES SPECIFIED
echo "$BINARYINSTALLS" | while read PACKAGE
do
echo Y | apt-get install $PACKAGE -y
done

#GET BUILDDEPS FOR THE PACKAGES SPECIFIED
echo "$BUILDINSTALLS" | while read PACKAGE
do
echo Y | apt-get build-dep $PACKAGE -y
done

##################################################################################################################




#For some reason, it installs out of date packages sometimes, as I see unupgraded packages
yes Y | apt-get dist-upgrade

#Do this as some packages fail to install completly unless if the attempt to start them as deamons succeeds. This will report success during those attempts to start the services to dpkg
mv /sbin/initctl /sbin/initctl.bak
ln -s /bin/true /sbin/initctl
yes Y | apt-get dist-upgrade
rm /sbin/initctl
mv  /sbin/initctl.bak /sbin/initctl

#get current list of packages
dpkg --get-selections > /tmp/oldpackages

#backup the state of the packages
cp /var/lib/dpkg/status  /var/lib/dpkg/status.backup

#trick dpkg to think everytiing is uninstalled
sed -i 's/install ok installed/deinstall ok config-files' /var/lib/dpkg/status

#FAKE INSTALL THE PACKAGES SPECIFIED TO GET LIST OF DEPENDS
echo "$BINARYINSTALLS" | while read PACKAGE
do
echo Y | apt-get install $PACKAGE -y -s >> /tmp/newpackages
done

#FAKE BUILDDEPS FOR THE PACKAGES SPECIFIED TO GET LIST OF DEPENDS
echo "$BUILDINSTALLS" | while read PACKAGE
do
echo Y | apt-get build-dep $PACKAGE -y -s >> /tmp/newpackages
done

#Place the state of the packages back
cp /var/lib/dpkg/status.backup  /var/lib/dpkg/status

#find packages that WHERE installed previously, but are no longer specified to BE installed
diff /tmp/oldpackages /tmp/newpackages | grep \< | awk '{print $2}' | while read PACKAGE
do
apt-get purge $PACKAGE
done

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only