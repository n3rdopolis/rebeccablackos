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

#Copy the import files into the system, and create menu items while creating a deb with checkinstall.
cd /tmp
mkdir debian
touch debian/control
#remove any old deb files for this package
rm "/srcbuild/buildoutput/"rbos-rbos_*.deb
checkinstall -y -D --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="expect,whois,dlocate,zenity,xterm,vpx-tools" /tmp/configure_phase3_helper.sh
cp *.deb "/srcbuild/buildoutput/"
cd $OLDPWD

#copy all files
rsync /usr/import/* -a /

#delete the import folder
rm -r /usr/import

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Turn the westonlaunchcaller in weston into a symlink
rm /opt/bin/weston
ln -s /usr/bin/westonlaunchcaller /opt/bin/weston

#save the build date of the CD.
echo "$(date)" > /etc/builddate

#start the remastersys job
remastersys dist

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso


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

#This will remove my abilities to build packages from the ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)

yes Y | apt-get purge $REMOVEDEVPGKS | tee /usr/share/logs/package_operations/removes.txt


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS | tee -a /usr/share/logs/package_operations/removes.txt


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS | tee -a /usr/share/logs/package_operations/removes.txt

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
yes Y | apt-get purge $REMOVEDEVPGKS | tee -a /usr/share/logs/package_operations/removes.txt

REMOVEDEVPGKS="texlive-base ubuntu-docs gnome-user-guide cmake libgl1-mesa-dri-dbg libglib2.0-doc valgrind cmake-rbos smbclient freepats libc6-dbg doxygen git subversion bzr mercurial checkinstall texinfo"
yes Y | apt-get purge $REMOVEDEVPGKS | tee -a /usr/share/logs/package_operations/removes.txt


yes Y | apt-get autoremove >> /usr/share/logs/package_operations/removes.txt

#Reset the utilites back to the way they are supposed to be.
rm /sbin/initctl
rm /usr/sbin/grub-probe
rm /usr/sbin/invoke-rc.d
dpkg-divert --local --rename --remove /usr/sbin/grub-probe
dpkg-divert --local --rename --remove /sbin/initctl
dpkg-divert --local --rename --remove /usr/sbin/invoke-rc.d

#hide buildlogs in tmp from remastersys
mv /usr/share/logs	/tmp

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
rm -r /opt/examples
rm -r /opt/translations

#Reduce binary sizes
echo "Reducing binary file sizes"
find /opt/bin /opt/lib /opt/sbin | while read FILE
do
  strip $FILE 2>/dev/null
done

#clean more apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/dlocate/*
#start the remastersys job
remastersys dist

#move logs back
mv /tmp/logs /usr/share

#Run the compile_all script in the mode that causes the cleanup routine to be run for each build scripts repository type
compile_all clean
