#! /bin/bash
#    Copyright (c) 2012 - 2023 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Require root privlages
if [[ $UID != 0 ]]
then
  echo "Must be run as root."
  exit
fi

#This file is used by checkinstall for creating the rbos-rbos package that has all of the installed SVN files

#Copy select files into place, that are suitable for distribution.
cp -a /usr/import/usr/* /usr

mkdir -p /etc/skel/.config
cp -a /usr/import/etc/skel/* /etc/skel
mkdir -p /etc/skel/Desktop

mkdir -p /etc/remastersys
cp -a /usr/import/etc/remastersys/* /etc/remastersys

mkdir -p /etc/pam.d
cp -a /usr/import/etc/pam.d/* /etc/pam.d

mkdir -p /etc/grub.d
cp -a /usr/import/etc/grub.d/* /etc/grub.d

mkdir -p /etc/loginmanagerdisplay
cp -a /usr/import/etc/loginmanagerdisplay/* /etc/loginmanagerdisplay

#Configure python to use modules in /opt
echo "/opt/lib/python2.7/site-packages" > "/usr/lib/python2.7/dist-packages/optpkgs.pth"
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
    ln -s /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd.pc /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd-$LIBRARY.pc
  fi
done

cp /usr/lib/os-release.rbos /usr/lib/os-release

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

#wlroots new renderer needs DRM Prime sharing enabled. These GPU drivers appear to not support it yet.  (they need to import DRM_GEM_SHMEM_DRIVER_OPS)
#Force these to fallback with SimpleDRM
echo "blacklist ast"          > /etc/modprobe.d/wlrootsdrmprime.conf
echo "blacklist gma500_gfx"  >> /etc/modprobe.d/wlrootsdrmprime.conf
echo "blacklist bochs"       >> /etc/modprobe.d/wlrootsdrmprime.conf
echo "blacklist vboxvideo"   >> /etc/modprobe.d/wlrootsdrmprime.conf
