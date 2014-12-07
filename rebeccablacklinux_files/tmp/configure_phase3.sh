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

#function to handle moving back dpkg redirect files for chroot
function RevertFile {
  TargetFile=$1
  SourceFile=$(dpkg-divert --truename "$1")
  if [[ "$TargetFile" != "$SourceFile" ]]
  then
    rm "$1"
    dpkg-divert --local --rename --remove "$1"
  fi
}

#function to handle temporarily moving files with dpkg that attempt to cause issues with chroot
function RedirectFile {
  RevertFile "$1"
  dpkg-divert --local --rename --add "$1" 
  ln -s /bin/true "$1"
}


#Copy the import files into the system, and create menu items while creating a deb with checkinstall.
cd /tmp
mkdir debian
touch debian/control
#remove any old deb files for this package
rm "/srcbuild/buildoutput/"rbos-rbos_*.deb
checkinstall -y -D --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="expect,whois,dlocate,zenity,xterm,vpx-tools,screen" /tmp/configure_phase3_helper.sh
cp *.deb "/srcbuild/buildoutput/"
cd $OLDPWD

#copy all files
rsync /usr/import/* -a /

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#disable systemd networkd, and enable NetworkManager
systemctl disable systemd-networkd.service
systemctl enable NetworkManager.service

#Enable and disable services to enable Ubuntu specific functionality, and for the waylandloginmanager
systemctl disable sandbox.service
systemctl enable make-mtab-symlink.service
systemctl enable make-fs-private.service
systemctl enable make-machine-id.service
systemctl enable mount-run-shm.service
systemctl enable configure-resolvconf.service
systemctl enable unset-grub-fail.service
systemctl enable waylandloginmanager.service
systemctl disable friendly-recovery.service
systemctl disable lightdm.service
systemctl disable gdm.service

#Make all systemd units nonexecutable
find /etc/systemd/system /lib/systemd/system /lib/udev/rules.d -type f | while read FILE
do
  chmod 644 "$FILE"
done

#Add groups for systemd
addgroup --system systemd-journal 
addgroup --system lock 

#Change the default init system to systemd if it exists
if [[ -e /lib/systemd/systemd ]]
then
  mv /sbin/init /sbin/init.upstart
  mv /lib/systemd/systemd /sbin/init
  ln -s /sbin/init /lib/systemd/systemd
fi

#Create the user for the waylandloginmanager
adduser --no-create-home --home=/etc/loginmanagerdisplay --shell=/bin/bash --disabled-password --system waylandloginmanager

#Complie glib schemas
glib-compile-schemas /opt/share/glib-2.0/schemas 

#Configure gnome-shell to use the unity control panel
sed 's/Exec=/Exec=waylandapp /g' /usr/share/applications/gnome-control-center.desktop > /opt/share/applications/gnome-control-center.desktop
sed 's/Exec=/Exec=waylandapp /g' /usr/share/applications/gnome-background-panel.desktop > /opt/share/applications/gnome-background-panel.desktop

#copy all files again to ensure that the SVN versions are not overwritten by a checkinstalled version
rsync /usr/import/* -a /

#delete the import folder
rm -r /usr/import

#save the build date of the CD.
echo "$(date)" > /etc/builddate

#Get all Source 
echo "#This script is used to specify the revisions of the repositories which the ISO was built with. See output of the main builder for how to use this file, if you want to build the exact revisions, instead of the latest ones" > /usr/share/build_core_revisions.txt
cat /usr/share/logs/build_core/*/GetSourceVersion >> /usr/share/build_core_revisions.txt

#hide buildlogs in tmp from remastersys
mv /usr/share/logs	/tmp

#start the remastersys job
remastersys dist

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso



#Redirect these utilitues to /bin/true during the live CD Build process. They aren't needed and cause package installs to complain
RedirectFile /usr/sbin/grub-probe
RedirectFile /sbin/initctl
RedirectFile /usr/sbin/invoke-rc.d

#This will remove my abilities to build packages from the ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)

apt-get purge $REMOVEDEVPGKS -y --force-yes | tee /tmp/logs/package_operations/removes.txt


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/removes.txt


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/removes.txt

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/removes.txt

REMOVEDEVPGKS="texlive-base ubuntu-docs gnome-user-guide cmake libgl1-mesa-dri-dbg libglib2.0-doc valgrind cmake-rbos smbclient freepats libc6-dbg doxygen git subversion bzr mercurial checkinstall texinfo autoconf"
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/removes.txt


apt-get autoremove -y --force-yes >> /tmp/logs/package_operations/removes.txt

#Reset the utilites back to the way they are supposed to be.
RevertFile /usr/sbin/grub-probe
RevertFile /sbin/initctl
RevertFile /usr/sbin/invoke-rc.d

#delete larger binary files that are for development, and are not needed on the smaller iso
rm /opt/bin/Xorg
rm /opt/bin/Xnest
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

#Delete all /opt includes
rm -rf /opt/include

#Reduce binary sizes
echo "Reducing binary file sizes"
find /opt/bin /opt/lib /opt/sbin /opt/games | while read FILE
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
