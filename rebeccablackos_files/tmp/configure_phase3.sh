#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

export PACKAGEOPERATIONLOGDIR=/var/log/buildlogs/package_operations

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


#Redirect some files that get changed
export DEBIAN_DISTRO=$(awk '{print $1}' /etc/issue)
if [[ $DEBIAN_DISTRO == Ubuntu ]]
then
  dpkg-divert --local --rename --add /lib/plymouth/ubuntu_logo.png
elif [[ $DEBIAN_DISTRO == Debian ]]
then
  dpkg-divert --local --rename --add /usr/share/plymouth/debian-logo.png
fi

if [[ $DEBIAN_DISTRO == Debian ]]
then
  echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
fi
#Create a folder for lightdm, so that casper and ubiquity configure autologin, as waylandloginmanager reads the config files
mkdir /etc/lightdm/

#Copy the import files into the system, while creating a deb with checkinstall.
cp /usr/import/tmp/* /tmp
cd /tmp
mkdir debian
touch debian/control
#remove any old deb files for this package
rm "/srcbuild/buildoutput/"rbos-rbos_*.deb
checkinstall -y -D --fstrans=no --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="expect,whois,dlocate,xterm,vpx-tools,screen,kbd,checkinstall,acl,xdg-utils,psmisc,kbd,bash-builtins" /tmp/configure_phase3_helper.sh
cd $OLDPWD

#Create a virtual configuration package for the waylandloginmanager
export DEBIAN_FRONTEND=noninteractive
cd /tmp/wlm-virtualpackage
chmod +x config
chmod +x postinst
tar czf control.tar.gz control config templates postinst
tar czf data.tar.gz -T /dev/null
ar q waylandloginmanager-rbos.deb debian-binary
ar q waylandloginmanager-rbos.deb control.tar.gz
ar q waylandloginmanager-rbos.deb data.tar.gz
dpkg -i waylandloginmanager-rbos.deb
cd $OLDPWD

#copy all files
rsync /usr/import/* -a /

#workaround for Debian not including legacy systemd files
export DEB_HOST_MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null)
echo -e "daemon\nid128\njournal\nlogin" | while read LIBRARY
do
  if [[ ! -e /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd-$LIBRARY.pc ]]
  then
    ln -s /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd.pc /usr/lib/$DEB_HOST_MULTIARCH/pkgconfig/libsystemd-$LIBRARY.pc
  fi
done

#Redirect grub-install if lupin isn't 1st tier
if [[ ! -e /usr/share/initramfs-tools/hooks/lupin_casper ]]
then
  dpkg-divert --add --rename --divert /usr/sbin/grub-install.real /usr/sbin/grub-install
  echo 'if [ -x /usr/sbin/grub-install.lupin ]; then /usr/sbin/grub-install.lupin "$@"; else /usr/sbin/grub-install.real "$@"; fi; exit $?' > /usr/sbin/grub-install
  chmod +x /usr/sbin/grub-install
fi

#Fall back to GCC 5 instead of GCC 6
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-6 100
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 50
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 100
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 50
update-alternatives --install /usr/bin/cpp cpp-bin /usr/bin/cpp-6 100
update-alternatives --install /usr/bin/cpp cpp-bin /usr/bin/cpp-5 50
update-alternatives --set g++ /usr/bin/g++-5
update-alternatives --set gcc /usr/bin/gcc-5
update-alternatives --set cpp-bin /usr/bin/cpp-5

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Create a package with all the menu items.
cd /tmp
rm "/srcbuild/buildoutput/"menuitems-rbos*.deb
checkinstall -y -D --fstrans=no --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=menuitems-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos install_menu_items
cp *.deb "/srcbuild/buildoutput/"
cd $OLDPWD

#Set the cursor theme
update-alternatives --set x-cursor-theme /etc/X11/cursors/oxy-white.theme

#Oxygen-Icons moved all the folders for icon sizes into a base folder, create symlinks for the old path
ln -s /usr/share/icons/oxygen/base/8x8 /usr/share/icons/oxygen/8x8
ln -s /usr/share/icons/oxygen/base/16x16 /usr/share/icons/oxygen/16x16
ln -s /usr/share/icons/oxygen/base/22x22 /usr/share/icons/oxygen/22x22
ln -s /usr/share/icons/oxygen/base/32x32 /usr/share/icons/oxygen/32x32
ln -s /usr/share/icons/oxygen/base/48x48 /usr/share/icons/oxygen/48x48
ln -s /usr/share/icons/oxygen/base/64x64 /usr/share/icons/oxygen/64x64
ln -s /usr/share/icons/oxygen/base/128x128 /usr/share/icons/oxygen/128x128
ln -s /usr/share/icons/oxygen/base/256x256 /usr/share/icons/oxygen/256x256

#Set the plymouth themes
if [[ $DEBIAN_DISTRO == Ubuntu ]]
then
  update-alternatives --install /lib/plymouth/themes/text.plymouth text.plymouth /lib/plymouth/themes/rebeccablackos-text/rebeccablackos-text.plymouth 100
  update-alternatives --set text.plymouth /lib/plymouth/themes/rebeccablackos-text/rebeccablackos-text.plymouth
  update-alternatives --set default.plymouth /lib/plymouth/themes/spinfinity/spinfinity.plymouth
elif [[ $DEBIAN_DISTRO == Debian ]]
then
  /usr/sbin/plymouth-set-default-theme spinfinity
fi

#configure /etc/issue
echo -e "RebeccaBlackOS \\\n \\\l \n" > /etc/issue
echo -e "RebeccaBlackOS \n" > /etc/issue.net

#configure grub color
echo "set color_normal=black/black" > /boot/grub/custom.cfg

#disable services that conflict with the waylandloginmanager
systemctl disable lightdm.service
systemctl disable gdm.service

#Create the user for the waylandloginmanager
adduser --no-create-home --home=/etc/loginmanagerdisplay --shell=/bin/bash --disabled-password --system --group waylandloginmanager

#Complie glib schemas
glib-compile-schemas /opt/share/glib-2.0/schemas 

#Configure gnome-control-panel to start with waylandapp for starting as a Wayland client
sed 's/Exec=/Exec=waylandapp /g' /usr/share/applications/gnome-control-center.desktop > /opt/share/applications/gnome-control-center.desktop
sed 's/Exec=/Exec=waylandapp /g' /usr/share/applications/gnome-background-panel.desktop > /opt/share/applications/gnome-background-panel.desktop

#ubiquity workaround. XWayland only permits applications that run as the user, so run it as a Wayland cleint
if [[ -e /usr/bin/ubiquity ]]
then
  dpkg-divert --add --rename --divert /usr/bin/ubiquity.real /usr/bin/ubiquity
  echo -e "#! /bin/bash\nwlsudo ubiquity.real" > /usr/bin/ubiquity
  chmod +x /usr/bin/ubiquity
fi

#copy all files again to ensure that the SVN versions are not overwritten by a checkinstalled version
rsync /usr/import/* -a /

#move the import folder
mv /usr/import /tmp

#Add nls modules to the initramfs
echo -e '#!/bin/sh\n. /usr/share/initramfs-tools/hook-functions\ncopy_modules_dir kernel/fs/nls' > /usr/share/initramfs-tools/hooks/nlsmodules
chmod 755 /usr/share/initramfs-tools/hooks/nlsmodules

#Uninstall the upstream kernel if there is a custom built kernel installed
if [[ $(dlocate /boot/vmlinuz |grep -c rbos ) != 0 ]]
then
  dpkg --get-selections | awk '{print $1}'| grep 'linux-image\|linux-headers' | grep -E \(linux-image-[0-9]'\.'[0-9]\|linux-headers-[0-9]'\.'[0-9]\) | while read PACKAGE
  do
    apt-get purge $PACKAGE -y
    #Force initramfs utilites to include the overlay filesystem
    echo overlay >> /etc/initramfs-tools/modules
  done
fi


#save the build date of the CD.
echo "$(date)" > /etc/builddate

#start the remastersys job
remastersys dist

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso



#Redirect these utilitues to /bin/true during the live CD Build process. They aren't needed and cause package installs to complain
RedirectFile /usr/sbin/grub-probe
RedirectFile /sbin/initctl
RedirectFile /usr/sbin/invoke-rc.d

#Configure dpkg
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/force-unsafe-io
echo "force-confold"   > /etc/dpkg/dpkg.cfg.d/force-confold
echo "force-confdef"   > /etc/dpkg/dpkg.cfg.d/force-confdef

#Create a log folder for the remove operations
mkdir "$PACKAGEOPERATIONLOGDIR"/Removes

#This will remove abilities to build packages from the reduced ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)

apt-get purge $REMOVEDEVPGKS -y | tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/devpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y | tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/archdevpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y | tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/dbgpackages.log

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y | tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/archdpgpackages.log

#Handle these packages one at a time, as they are not automatically generated. one incorrect specification and apt-get quits. The automatic generated ones are done with one apt-get command for speed
REMOVEDEVPGKS=(texlive-base gnome-user-guide cmake libgl1-mesa-dri-dbg libglib2.0-doc valgrind smbclient freepats libc6-dbg doxygen git subversion bzr mercurial texinfo autoconf cpp-5 gcc-5 g++-5 unicode-data texinfo)
for (( Iterator = 0; Iterator < ${#REMOVEDEVPGKS[@]}; Iterator++ ))
do
  REMOVEPACKAGENAME=${REMOVEDEVPGKS[$Iterator]}
  apt-get purge $REMOVEPACKAGENAME -y | tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/$REMOVEPACKAGENAME.log
done

apt-get autoremove -y | tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/autoremoves.log

#Install the reduced packages
compile_all installsmallpackage 

#copy all files again to ensure that the SVN versions are not overwritten by a checkinstalled version
rsync /tmp/import/* -a /


#Reset the utilites back to the way they are supposed to be.
RevertFile /usr/sbin/grub-probe
RevertFile /sbin/initctl
RevertFile /usr/sbin/invoke-rc.d

#set dpkg to defaults
rm /etc/dpkg/dpkg.cfg.d/force-unsafe-io
rm /etc/dpkg/dpkg.cfg.d/force-confold
rm /etc/dpkg/dpkg.cfg.d/force-confdef

#clean more apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/dlocate/*
#start the remastersys job
remastersys dist
