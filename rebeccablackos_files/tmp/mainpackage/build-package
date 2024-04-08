#! /bin/bash
#    Copyright (c) 2012 - 2024 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
#
#    This file is part of RebeccaBlackOS.
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
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

#Require root privlages
if [[ $UID != 0 ]]
then
  echo "Must be run as root."
  exit
fi

shopt -s dotglob

  #This file is used by checkinstall for creating the rbos-rbos package that has all of the installed SVN files

#Copy select files into place, that are suitable for distribution.
cp -a /usr/import/usr/* /usr

mkdir -p /etc/skel/.config
cp -a /usr/import/etc/* /etc/
mkdir -p /etc/skel/Desktop

#Make the 'hidden' waylandloginmanager zenity to kdialog convert script executable
chmod 755 /usr/share/RBOS_PATCHES/wlm-zenity-kdialog

#Configure python to use modules in /opt
echo "/opt/lib/python3/dist-packages" >> "/usr/lib/python3/dist-packages/optpkgs.pth"
PYTHON3DIRS=$(find /usr/lib/python3* -maxdepth 0 -printf "%f\n")
for PYTHON3DIR in $PYTHON3DIRS
do
echo "/opt/lib/$PYTHON3DIR/site-packages" >> "/usr/lib/python3/dist-packages/optpkgs.pth"
done

#workaround for Debian not including legacy systemd files
export DEB_HOST_MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
echo -e "daemon\nid128\njournal\nlogin" | while read -r LIBRARY
do
  if [[ ! -e /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd-$LIBRARY.pc ]]
  then
    ln -sf /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd.pc /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd-$LIBRARY.pc
  fi
done

#ibus workaround
ln -sf /usr/share/unicode/ /usr/share/unicode/ucd

ln -sf /usr/lib/os-release.rbos /etc/os-release

#configure /etc/issue
echo -e "RebeccaBlackOS \\\n \\\l \n" > /etc/issue
setterm -cursor on >> /etc/issue
echo -e "RebeccaBlackOS \n" > /etc/issue.net

#Add libraries under /opt to the ldconfig cache, for setcap'ed binaries
echo /opt/lib >> /etc/ld.so.conf.d/aa_rbos_opt_libs.conf
echo /opt/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null) >> /etc/ld.so.conf.d/aa_rbos_opt_libs.conf

#save the build date of the CD.
date -u +"%A, %Y-%m-%d %H:%M:%S %Z" > /etc/builddate

if [[ $DEBIAN_DISTRO == Debian ]]
then
  echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
fi
echo "blacklist udlfb" > /etc/modprobe.d/udlkmsonly.conf
echo "blacklist evbug" > /etc/modprobe.d/evbug.conf

#Create a default /etc/vconsole.conf for plymouth
echo "XKBLAYOUT=\"us\"" >> /etc/vconsole.conf
echo "XKBMODEL=\"pc105\"" >> /etc/vconsole.conf
echo "XKBVARIANT=\"\"" >> /etc/vconsole.conf
echo "XKBOPTIONS=\"\"" >> /etc/vconsole.conf

#Create a python path
mkdir -p /opt/lib/$(readlink /usr/bin/python3)/site-packages/

#Create a /opt/var/log folder
mkdir -p /opt/var/log

#Replace X symlink
ln -sf /opt/bin/Xorg /usr/bin/X

#Create a link to plymouth
ln -sf /opt/bin/plymouth /usr/bin/plymouth

#Replace chvt with the seat aware wrapper
ln -sf /usr/bin/chvt-logind /usr/bin/chvt

#include /etc/loginmanagerdisplay/dconf/waylandloginmanager-dconf-defaults as part of the package, the contents get generated later when dconf is actually built
touch /etc/loginmanagerdisplay/dconf/waylandloginmanager-dconf-defaults

#Set the bootsplash for remastersys
ln -sf /usr/share/wallpapers/RBOS_Login/contents/images/1920x1200.png /etc/remastersys/isolinux/splash.png
