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

#replace all of remastersys's unames with the installed kernel version.
sed -i "s/\`uname -r\`/$KERNELVERSION/g" /usr/bin/remastersys

#save the build date of the CD.
echo "$(date)" > /etc/builddate

#delete the build source (from the phase 2 snapshot) so it doesn't bloat the live cd
rm -rf /srcbuild

#install the menu items for the wayland tests
install_menu_items



#This will remove my abilities to build packages from the ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS
echo $REMOVEDEVPGKS > /usr/share/RemovedPackages.txt

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:i386$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS
echo $REMOVEDEVPGKS >> /usr/share/RemovedPackages.txt

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS
echo $REMOVEDEVPGKS >> /usr/share/RemovedPackages.txt

REMOVEDEVPGKS="texlive-base ubuntu-docs gnome-user-guide subversion git libllvm3.0 samba-common-bin libglib2.0-doc"
yes Y | apt-get purge $REMOVEDEVPGKS
echo $REMOVEDEVPGKS >> /usr/share/RemovedPackages.txt

apt-get autoremove -s | awk '{print $2}' >> /usr/share/RemovedPackages.txt
yes Y | apt-get autoremove

#remove duplicated samples
rm -rf /opt/examples

#clean more apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
rm -rf /var/cache/debconf/*
rm -rf /var/lib/apt/lists/*

#Make the executables smaller
echo "Reducing binary file sizes"
find /opt/bin /opt/lib /opt/sbin | while read FILE
do
strip $FILE 2>/dev/null
done

#start the remastersys job
remastersys dist




