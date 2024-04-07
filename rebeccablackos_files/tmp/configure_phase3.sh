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

export PACKAGEOPERATIONLOGDIR=/var/log/buildlogs/package_operations

#Create a log folder for the package operations
mkdir "$PACKAGEOPERATIONLOGDIR"/phase_3

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

#redirect files from tier 1 Debian packages
mkdir /var/lib/divert-distrib
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/etc_default_grub /etc/default/grub
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/etc_skel_.bashrc /etc/skel/.bashrc
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/etc_issue        /etc/issue
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/etc_issue.net    /etc/issue.net
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/etc_os-release   /etc/os-release
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/etc_lsb-release  /etc/lsb-release
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/usr_bin_X        /usr/bin/X
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/usr_bin_plymouth /usr/bin/plymouth
dpkg-divert --package rbos-rbos --add --rename --divert /var/lib/divert-distrib/usr_bin_chvt /usr/bin/chvt

if [[ -f /tmp/APTFETCHDATE ]]
then
  PACKAGEDATE=$(cat "/tmp/APTFETCHDATE" | grep -v ^$| awk -F = '{print $2}')
else
  PACKAGEDATE=$(date +%s)
fi

#Set the pager to not be interactive
export PAGER=cat

#Copy the import files into the system, while creating a deb with checkinstall.
cp /usr/import/tmp/* /tmp

#copy all the files to import
rsync -Ka -- /usr/import/* /
chmod 777 /tmp


mkdir /tmp/debian
touch /tmp/debian/control
#remove any old deb files for this package
rm "/var/cache/srcbuild/buildoutput/"rbos-rbos_*.deb
env -C /tmp -- /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="" --exclude=/var/cache/srcbuild,/home/remastersys,/var/tmp,/var/log/buildlogs /tmp/configure_phase3_helper.sh

#Create a virtual configuration package for the waylandloginmanager
export DEBIAN_FRONTEND=noninteractive
mkdir -p /tmp/wlm-virtualpackage
chmod +x /tmp/wlm-virtualpackage/config
chmod +x /tmp/wlm-virtualpackage/postinst
env -C /tmp/wlm-virtualpackage -- tar czf control.tar.gz control config templates postinst
env -C /tmp/wlm-virtualpackage -- tar czf data.tar.gz -T /dev/null
env -C /tmp/wlm-virtualpackage -- ar q waylandloginmanager-rbos.deb debian-binary
env -C /tmp/wlm-virtualpackage -- ar q waylandloginmanager-rbos.deb control.tar.gz
env -C /tmp/wlm-virtualpackage -- ar q waylandloginmanager-rbos.deb data.tar.gz
dpkg --force-overwrite --force-confmiss --force-confnew -i /tmp/wlm-virtualpackage/waylandloginmanager-rbos.deb

#Force CRYPTSETUP to be enabled, so that needed files are already copied
echo "export CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook

#Configure a locale so that the initramfs doesn't have to
update-locale LANG=en_US.UTF-8

#Remove the rust lock file from previous builds in case the download process for rust stopped before it completed
if [[ -e /var/cache/srcbuild/buildhome/buildcore_rust/lockfile ]]
then
  rm /var/cache/srcbuild/buildhome/buildcore_rust/lockfile &> /dev/null
fi

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Actions that are performed after all the packages are compiled
function PostInstallActions
{
  #Append the snapshot date to the end of the revisions file
  cat /tmp/APTFETCHDATE >> /usr/share/buildcore_revisions.txt

  #Create a package with all the menu items.
  rm "/var/cache/srcbuild/buildoutput/"menuitems-rbos*.deb
  env -C /tmp -- /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=menuitems-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos install_menu_items

  rm "/var/cache/srcbuild/buildoutput/"buildcorerevisions-rbos*.deb
  env -C /tmp -- /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=buildcorerevisions-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --exclude=/var/cache/srcbuild,/home/remastersys,/var/tmp,/var/log/buildlogs touch /usr/share/buildcore_revisions.txt

  cp /tmp/*.deb "/var/cache/srcbuild/buildoutput/"

  #Set the cursor theme
  update-alternatives --set x-cursor-theme /etc/X11/cursors/oxy-white.theme

  #configure grub color
  echo "set color_normal=black/black" > /boot/grub/custom.cfg

  #disable services that conflict with the waylandloginmanager
  systemctl disable gdm.service

  #Don't run ssh by default
  systemctl disable ssh.service

  #Enable networkmanager
  systemctl enable NetworkManager.service
  
  #enable acpid
  systemctl enable acpid.service
  
  #enable upower
  systemctl enable upower.service

  #enable the virtual tty services.
  systemctl enable vtty-frontend@.service
  ln -s /usr/lib/systemd/system/vtty-frontend@.service /etc/systemd/system/autovt@.service

  #Enable the auto simpledrm fallback detector
  systemctl enable auto_simpledrm_fallback.service

  #Enable the recinit services for systemd's recovery shells
  systemctl enable recinit-rescue.service
  systemctl enable recinit-emergency.service

  #Enable pipewire services
  systemctl --global enable pipewire.socket
  systemctl --global add-wants pipewire.service wireplumber.service
  systemctl --global enable pipewire-pulse.socket

  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; ldconfig)

  #common postinstall actions
  echo "Post Install action: glib-compile-schemas"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; glib-compile-schemas /opt/share/glib-2.0/schemas)
  echo "Post Install action: update-desktop-database"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; update-desktop-database /opt/share/applications)
  echo "Post Install action: gtk-query-immodules-3.0"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; gtk-query-immodules-3.0 --update-cache)
  echo "Post Install action: update-icon-caches"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; update-icon-caches /opt/share/icons/*)
  echo "Post Install action: gio-querymodules"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; gio-querymodules /opt/lib/$DEB_HOST_MULTIARCH/gio/modules)
  echo "Post Install action: gdk-pixbuf-query-loaders"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; gdk-pixbuf-query-loaders > /opt/lib/$DEB_HOST_MULTIARCH/gdk-pixbuf-2.0/2.10.0/loaders.cache)
  echo "Post Install action: fc-cache"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; fc-cache)
  echo "Post Install action: Plymouth theme"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; /opt/sbin/plymouth-set-default-theme spinner)
  echo "Post Install action: Create dconf config for the loginmanagerdisplay"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; dconf compile /etc/loginmanagerdisplay/dconf/waylandloginmanager-dconf-defaults /etc/loginmanagerdisplay/dconf/dconfimport)

  echo "Post Install action: Configure dbus and polkit"

  #Force the current files to be true, if a package build process accidentally added an imported file (by touching the file)
  #The cached built deb would accidentally overwrite the latest version, install the built deb with the current files.
  dpkg --force-overwrite --force-confmiss --force-confnew -i /var/cache/srcbuild/buildoutput/rbos-rbos_1-${PACKAGEDATE}_${BUILDARCH}.deb

  #move the import folder
  mv /usr/import /tmp

  #Force initramfs utilites to include the overlay filesystem
  echo overlay >> /etc/initramfs-tools/modules
}
PostInstallActions |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/0_PostInstallActions.log

#clean apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
find /var/lib/apt/lists ! -type d -delete
rm -rf /var/lib/dlocate/*

#start the remastersys job
(. /usr/bin/build_vars; remastersys dist)
mv /home/remastersys/remastersys/custom.iso /home/remastersys/custom-full.iso
rm -rf /home/remastersys/remastersys/*


#Redirect these utilitues to /bin/true during the live CD Build process. They aren't needed and cause package installs to complain
RedirectFile /usr/sbin/grub-probe
RedirectFile /sbin/initctl
RedirectFile /usr/sbin/invoke-rc.d

#Configure dpkg
echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/force-unsafe-io
echo "force-confold"   > /etc/dpkg/dpkg.cfg.d/force-confold
echo "force-confdef"   > /etc/dpkg/dpkg.cfg.d/force-confdef

#This will remove abilities to build packages from the reduced ISO, but should make it a bit smaller
REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev$"  | grep -v dpkg-dev)

apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/1_devpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/2_archdevpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/3_dbgpackages.log

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/4_archdpgpackages.log

#Handle these packages one at a time, as they are not automatically generated. one incorrect specification and apt-get quits. The automatic generated ones are done with one apt-get command for speed
REMOVEDEVPGKS=""
REMOVEDEVPGKSPROPOSED=(nodejs texlive-base gnome-user-guide cmake libgl1-mesa-dri-dbg libgl1-mesa-dri libglib2.0-doc valgrind smbclient freepats libc6-dbg doxygen git subversion bzr mercurial autoconf texinfo rustc cpp cpp-9 cpp-10 gcc gcc-9 gcc-10 g++ g++-9 g++-10 clang llvm-9 docbook-xsl linux-headers-"*")
for (( Iterator = 0; Iterator < ${#REMOVEDEVPGKSPROPOSED[@]}; Iterator++ ))
do
  PACKAGE=${REMOVEDEVPGKSPROPOSED[Iterator]}
  AvailableCount=$(dpkg --get-selections | awk '{print $1}' | awk -F : '{print $1}' | grep -c ^$PACKAGE$)
  if [[ $AvailableCount != 0 ]]
  then
    REMOVEDEVPGKS+="$PACKAGE "
  fi
done
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/5_Purges.log

apt-get autoremove -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/6_autoremoves.log

#remove the built packages so that the smaller ones can be installed cleanly
REMOVEDBGBUILTPKGS=$(dpkg --get-selections | awk '{print $1}' | grep '\-rbos$'| grep -v rbos-rbos | grep -v menuitems-rbos | grep -v buildcorerevisions-rbos)
apt-get purge $REMOVEDBGBUILTPKGS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/7_devbuiltpackages.log

#Install the reduced packages
compile_all installsmallpackage 


#Force the current files to be true, if a package build process accidentally added an imported file (by touching the file)
#The cached built deb would accidentally overwrite the latest version, install the built deb with the current files.
dpkg --force-overwrite --force-confmiss --force-confnew -i /var/cache/srcbuild/buildoutput/rbos-rbos_1-${PACKAGEDATE}_${BUILDARCH}.deb


#Reset the utilites back to the way they are supposed to be.
RevertFile /usr/sbin/grub-probe
RevertFile /sbin/initctl
RevertFile /usr/sbin/invoke-rc.d

#set dpkg to defaults
rm /etc/dpkg/dpkg.cfg.d/force-unsafe-io
rm /etc/dpkg/dpkg.cfg.d/force-confold
rm /etc/dpkg/dpkg.cfg.d/force-confdef

#Rebuild the library cache
(. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; ldconfig)

#Reconfigue Plymouth
(. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; /opt/sbin/plymouth-set-default-theme spinner)
#start the remastersys job
(. /usr/bin/build_vars; remastersys dist)
mv /home/remastersys/remastersys/custom.iso /home/remastersys/custom.iso
rm -rf /home/remastersys/remastersys/*

cp /usr/share/buildcore_revisions.txt /home/remastersys/
