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

# configure plymouth to use framebuffer
echo FRAMEBUFFER=y > /etc/initramfs-tools/conf.d/splash

#Copy the import files into the system, and create menu items while creating a deb with checkinstall.
cd /tmp
mkdir debian
touch debian/control
#remove any old deb files for this package
rm "/srcbuild/buildoutput/"rbos-rbos_*.deb
checkinstall -y -D --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="subversion,git,bzr,dlocate,vinagre,shotwell,seahorse,alacarte,checkinstall,zenity,transmission-gtk,gnome-games,gucharmap,gnome-font-viewer,pcmanfm,xterm,plasma-widget-networkmanagement,plasma-widget-veromix,kde-baseapps-bin,gedit,file-roller,vpx-tools,plasma-widget-folderview,plasma-widgets-workspace" /tmp/configure_phase3_helper.sh
cp *.deb "/srcbuild/buildoutput/"
cd $OLDPWD

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

#Remastersys deletes the tty startup files, and disables the ttys. Don't allow it to do so
sed -i 's/rm -f \$WORKDIR\/dummysys\/etc\/init\/tty?.conf//g'  /usr/bin/remastersys

#Remastersys now formats the ISO so it can be 'dd'ed onto a flash drive. However it creates a warning that not all BIOSes might like it, and might be what makes the ISO creation phase slower. This feature can be replaced with unetbootin or the USB startup creator, as it is easier for the user as well
grep -v "hybrid" /usr/bin/remastersys > /usr/bin/remastersys.bak
cat /usr/bin/remastersys.bak > /usr/bin/remastersys
rm /usr/bin/remastersys.bak

#save the build date of the CD.
echo "$(date)" > /etc/builddate

#start the remastersys job
remastersys dist

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso

#This will remove my abilities to build packages from the ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)

yes Y | apt-get purge $REMOVEDEVPGKS > /usr/share/logs/package_operations/removes.txt


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS >> /usr/share/logs/package_operations/removes.txt


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS >> /usr/share/logs/package_operations/removes.txt


REMOVEDEVPGKS="texlive-base ubuntu-docs gnome-user-guide cmake libgl1-mesa-dri-dbg libglib2.0-doc"
yes Y | apt-get purge $REMOVEDEVPGKS >> /usr/share/logs/package_operations/removes.txt


yes Y | apt-get autoremove >> /usr/share/logs/package_operations/removes.txt

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


