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

#install aptitude
yes Y| apt-get install aptitude

#LIST OF PACKAGES TO GET INSTALLED
BINARYINSTALLS="apt-rdepends:PART
bash-completion:FULL
lupin-casper:PART
libsqlite3-dev:PART
language-pack-en:FULL
linux-generic:FULL
llvm:PART
libxkbcommon-dev:PART
manpages:FULL
build-essential:PART
doxygen:PART
libtool:PART
libxi-dev:PART
libxmu-dev:PART
libxt-dev:PART
bison:PART
flex:PART
libgl1-mesa-dev:PART
xutils-dev:PART
libtalloc-dev:PART
libdrm-dev:PART
autoconf:PART
x11proto-kb-dev:PART
libegl1-mesa-dev:PART
libgles2-mesa-dev:PART
libgdk-pixbuf2.0-dev:PART
libudev-dev:PART
libxcb-dri2-0-dev:PART
libxcb-xfixes0:PART
libxcb-xfixes0-dev:PART
libxcb-randr0:PART
libxcb-randr0-dev:PART
libxcb-render-util0:PART
libxcb-render-util0-dev:PART
shtool:PART
libffi-dev:PART
libpoppler-glib-dev:PART 
libgtk2.0-dev:PART
git:PART
diffstat:PART 
bzr:PART
libx11-xcb-dev:PART
quilt:PART
autopoint:PART
dh-autoreconf:PART
xkb-data:PART
gtk-doc-tools:PART
gobject-introspection:PART 
gperf:PART
librsvg2-bin:PART 
libpciaccess-dev:PART 
python-libxml2:PART
libjpeg-dev:PART
libtiff-dev:PART
libvpx-dev:PART
libgbm-dev:PART
libxcb-glx0-dev:PART 
libgl1-mesa-dri-dbg:PART
ubuntu-standard:FULL
lightdm:FULL
kde-plasma-desktop:FULL
libpam-xdg-support:FULL
kmix:FULL
lightdm-kde-greeter:FULL
kubuntu-default-settings:FULL   
plasma-widget-networkmanagement:FULL
plymouth-theme-kubuntu-logo:FULL
plymouth-theme-kubuntu-text:FULL
xcursor-themes:PART
xfonts-utils:PART
nouveau-firmware:FULL
firefox:FULL
gedit:FULL
file-roller:FULL 
clutter-1.0-tests:PART
ncurses-dev:PART
libmtdev-dev:PART
libx11-xcb-dev:PART
libxcb1-dev:PART
libxcb-keysyms1-dev:PART 
libxcb-image0-dev:PART
libxcb-shm0:PART
libxcb-shm0-dev:PART
libxcb-icccm4:PART
libxcb-icccm4-dev:PART
libxcb-sync0:PART
libxcb-sync0-dev:PART 
libxcb-xfixes0-dev:PART
libgtk-3-dev:PART
libgio2.0-cil-dev:PART 
libjson-glib-dev:PART
x11proto-xcmisc-dev:PART 
x11proto-bigreqs-dev:PART
x11proto-fonts-dev:PART
x11proto-video-dev:PART
x11proto-record-dev:PART
x11proto-resource-dev:PART
libxkbfile-dev:PART
libxfont-dev:PART
libxext-dev:PART
xserver-xorg-dev:PART
x11proto-xf86dri-dev:PART
x11proto-xext-dev:PART
libqjson-dev:PART
libxcb1:PART
libx11-xcb1:PART
libxcb-dri2-0:PART
libxcb-xfixes0:PART
libxcb-keysyms1:PART
libxcb-image0:PART
subversion:PART
subversion-tools:PART
e17:FULL
nano:PART
libicu-dev:PART
libraptor-dev:PART
libegl1-mesa:PART
ubuntu-minimal:FULL
xserver-xorg:FULL
xterm:FULL
vpx-tools:PART
libkactivities-dev:PART
libqimageblitz-dev:PART
kde-workspace-dev:PART
zenity:FULL
lsb-desktop:FULL
ubiquity-frontend-kde:FULL
ubuntu-standard:FULL
remastersys:FULL"

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
echo "$BINARYINSTALLS" | while read PACKAGEINSTRUCTION
do
PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F '{print $1}' )
METHOD=$(echo $PACKAGEINSTRUCTION | awk -F '{print $2}' )

if [[ $METHOD == "PART" ]]
then
yes Yes | apt-get --no-install-recommends install $PACKAGE -y --force-yes
else
yes Yes | apt-get install $PACKAGE -y --force-yes
fi

done

#INSTALL THE PACKAGES SPECIFIED
echo "$FULLBINARYINSTALLS" | while read PACKAGE
do
echo "installing $PACKAGE"

done

#GET BUILDDEPS FOR THE PACKAGES SPECIFIED
echo "$BUILDINSTALLS" | while read PACKAGE
do
echo "installing $PACKAGE"
yes Y | apt-get build-dep $PACKAGE -y --force-yes
done

##################################################################################################################




#For some reason, it installs out of date packages sometimes, as I see unupgraded packages
yes Y | apt-get dist-upgrade 

#remove old kernels!
CURRENTKERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3}')
dpkg --get-selections | awk '{print $1}' | grep -v "$CURRENTKERNELVERSION" | grep linux-image | grep -v linux-image-generic | while read PACKAGE
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

#remastersys doesn't put in tmp into the live cds. symlink srcbuild into tmp, so that it can be unlinked from root, and the cmake uninstaller will still exist for the second image
mkdir /tmp/srcbuild
ln -s /tmp/srcbuild /srcbuild 

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only