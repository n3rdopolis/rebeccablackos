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

# /lib/plymouth/ubuntu-logo.png
echo FRAMEBUFFER=y > /etc/initramfs-tools/conf.d/splash

#remove packages that cause conflict
yes Yes |apt-get remove gdm gnome-session -y

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


#save the build date of the CD.
echo "$(date)" > /etc/builddate



#install the menu items for the wayland tests
install_menu_items

#unlink srcbuild symlink
rm /srcbuild

#start the remastersys job
remastersys dist

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso

#uninstall cmake
make -C /srcbuild/cmake uninstall

#delete the build source (from the phase 2 snapshot) so it doesn't bloat the live cd
rm -rf /srcbuild

#This will remove my abilities to build packages from the ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -s | grep Purg | awk '{print $2}' >> /usr/share/RemovedPackages.txt
yes Y | apt-get purge $REMOVEDEVPGKS


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -s | grep Purg | awk '{print $2}' >> /usr/share/RemovedPackages.txt
yes Y | apt-get purge $REMOVEDEVPGKS


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -s | grep Purg | awk '{print $2}' >> /usr/share/RemovedPackages.txt
yes Y | apt-get purge $REMOVEDEVPGKS


REMOVEDEVPGKS="texlive-base ubuntu-docs gnome-user-guide subversion git bzr cmake libgl1-mesa-dri-dbg libglib2.0-doc"
apt-get purge $REMOVEDEVPGKS -s | grep Purg | awk '{print $2}' >> /usr/share/RemovedPackages.txt
yes Y | apt-get purge $REMOVEDEVPGKS


apt-get autoremove -s | grep Remv | awk '{print $2}' >> /usr/share/RemovedPackages.txt
yes Y | apt-get autoremove

#hide buildlogs in tmp from remastersys
mv -r /usr/share/Buildlog     /tmp
mv -r  /usr/share/Downloadlog /tmp

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

#Make the executables smaller
echo "Reducing binary file sizes"
find /opt/bin /opt/lib /opt/sbin | while read FILE
do
strip $FILE 2>/dev/null
done

#start the remastersys job
remastersys dist

#move logs back
mv -r /tmp/Buildlog /usr/share
mv -r /tmp/Downloadlog /usr/share


