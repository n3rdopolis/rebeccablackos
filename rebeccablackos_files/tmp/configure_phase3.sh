#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
checkinstall -y -D --fstrans=no --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="expect,whois,dlocate,zenity,xterm,vpx-tools,screen,kbd,checkinstall,acl,xdg-utils" /tmp/configure_phase3_helper.sh
cd $OLDPWD

#Create a virtual configuration package for the waylandloginmanager
export DEBIAN_FRONTEND=noninteractive
cd /tmp/wlm-virtualpackage
chmod +x config
chmod +x postinst
tar czf control.tar.gz control config templates postinst
tar czf data.tar.gz -T /dev/null
ar q waylandloginmanager.deb debian-binary
ar q waylandloginmanager.deb control.tar.gz
ar q waylandloginmanager.deb data.tar.gz
dpkg -i waylandloginmanager.deb
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

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Create a package with all the menu items.
cd /tmp
rm "/srcbuild/buildoutput/"rbos-menuitems*.deb
checkinstall -y -D --fstrans=no --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-menuitems --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos install_menu_items
cp *.deb "/srcbuild/buildoutput/"
cd $OLDPWD

#Set the cursor theme
update-alternatives --set x-cursor-theme /etc/X11/cursors/oxy-white.theme

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

#Enable and disable services to enable Ubuntu specific functionality, and for the waylandloginmanager
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

#delete the import folder
rm -r /usr/import

#Uninstall the upstream kernel if there is a custom built kernel installed
if [[ $(dlocate /boot/vmlinuz |grep -c rbos ) != 0 ]]
then
  dpkg --get-selections | awk '{print $1}'| grep 'linux-image\|linux-headers' | grep -E \(linux-image-[0-9]'\.'[0-9]\|linux-headers-[0-9]'\.'[0-9]\) | while read PACKAGE
  do
    apt-get purge $PACKAGE -y --force-yes 
    #Force initramfs utilites to include the overlay filesystem
    echo overlay >> /etc/initramfs-tools/modules
  done
fi


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

#Create a log folder for the remove operations
mkdir /tmp/logs/package_operations/Removes

#This will remove abilities to build packages from the reduced ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v python-dbus-dev | grep -v dpkg-dev)

apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/Removes/devpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/Removes/archdevpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/Removes/dbgpackages.log

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v python-dbus-dev | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y --force-yes | tee -a /tmp/logs/package_operations/Removes/archdpgpackages.log

#Handle these packages one at a time, as they are not automatically generated. one incorrect specification and apt-get quits. The automatic generated ones are done with one apt-get command for speed
REMOVEDEVPGKS=(texlive-base ubuntu-docs gnome-user-guide cmake libgl1-mesa-dri-dbg libglib2.0-doc valgrind cmake-rbos smbclient freepats libc6-dbg doxygen git subversion bzr mercurial texinfo autoconf)
for (( Iterator = 0; Iterator < ${#REMOVEDEVPGKS[@]}; Iterator++ ))
do
  REMOVEPACKAGENAME=${REMOVEDEVPGKS[$Iterator]}
  apt-get purge $REMOVEPACKAGENAME -y --force-yes | tee -a /tmp/logs/package_operations/Removes/$REMOVEPACKAGENAME.log
done

apt-get autoremove -y --force-yes | tee -a /tmp/logs/package_operations/Removes/autoremoves.log

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
