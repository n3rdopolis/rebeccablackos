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

shopt -s dotglob

export PACKAGEOPERATIONLOGDIR=/buildlogs/package_operations

#Create a log folder for the remove operations
mkdir "$PACKAGEOPERATIONLOGDIR"/Removes

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

dpkg-divert --package rbos-rbos --add --rename --divert /etc/skel/.bashrc.distrib /etc/skel/.bashrc
dpkg-divert --package rbos-rbos --add --rename --divert /etc/issue.distrib /etc/issue
dpkg-divert --package rbos-rbos --add --rename --divert /etc/issue.net.distrib /etc/issue.net
dpkg-divert --package rbos-rbos --add --rename --divert /etc/os-release.distrib /etc/os-release
dpkg-divert --package rbos-rbos --add --rename --divert /etc/lsb-release.distrib /etc/lsb-release
dpkg-divert --package rbos-rbos --add --rename --divert /usr/bin/chvt.console /usr/bin/chvt
dpkg-divert --package rbos-rbos --add --rename --divert /usr/bin/X.distrib /usr/bin/X

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

cd /tmp
mkdir debian
touch debian/control
#remove any old deb files for this package
rm "/srcbuild/buildoutput/"rbos-rbos_*.deb
/usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="" /tmp/configure_phase3_helper.sh
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
dpkg --force-overwrite --force-confmiss --force-confnew -i waylandloginmanager-rbos.deb
cd $OLDPWD

#Force CRYPTSETUP to be enabled, so that needed files are already copied
echo "export CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook

#Set default user groups
printf "\nADD_EXTRA_GROUPS=1\nEXTRA_GROUPS="systemd-journald"\n" >> /etc/adduser.conf

#Configure a locale so that the initramfs doesn't have to
update-locale LANG=en_US.UTF-8

#Remove the rust lock file from previous builds in case the download process for rust stopped before it completed
if [[ -e /srcbuild/buildhome/buildcore_rust/lockfile ]]
then
  rm /srcbuild/buildhome/buildcore_rust/lockfile &> /dev/null
fi

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Actions that are performed after all the packages are compiled
function PostInstallActions
{
  #Append the snapshot date to the end of the revisions file
  cat /tmp/APTFETCHDATE >> /usr/share/buildcore_revisions.txt

  #Create a package with all the menu items.
  cd /tmp
  rm "/srcbuild/buildoutput/"menuitems-rbos*.deb
  /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=menuitems-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos install_menu_items

  rm "/srcbuild/buildoutput/"buildcorerevisions-rbos*.deb
  /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=buildcorerevisions-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos touch /usr/share/buildcore_revisions.txt

  rm "/srcbuild/buildoutput/"integrationsymlinks-rbos*.deb
  /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=integrationsymlinks-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="" /tmp/configure_phase3_symlinks.sh

  cp *.deb "/srcbuild/buildoutput/"
  cd $OLDPWD

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
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; /opt/sbin/plymouth-set-default-theme spinfinity)
  echo "Post Install action: Create dconf config for the loginmanagerdisplay"
  (. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; dconf compile /etc/loginmanagerdisplay/dconf/waylandloginmanager-dconf-defaults /etc/loginmanagerdisplay/dconf/dconfimport)

  echo "Post Install action: Configure dbus and polkit"

  #Force the current files to be true, if a package build process accidentally added an imported file (by touching the file)
  #The cached built deb would accidentally overwrite the latest version, install the built deb with the current files.
  dpkg --force-overwrite --force-confmiss --force-confnew -i /srcbuild/buildoutput/rbos-rbos_1-${PACKAGEDATE}_${BUILDARCH}.deb

  #move the import folder
  mv /usr/import /tmp
  
  #Make the 'hidden' waylandloginmanager zenity to kdialog convert script executable
  chmod 755 /usr/share/RBOS_PATCHES/wlm-zenity-kdialog

  #Force initramfs utilites to include the overlay filesystem
  echo overlay >> /etc/initramfs-tools/modules
}
PostInstallActions |& tee -a "$PACKAGEOPERATIONLOGDIR"/PostInstallActions.log

#clean apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
find /var/lib/apt/lists ! -type d -delete
rm -rf /var/lib/dlocate/*

#start the remastersys job
(. /usr/bin/build_vars; remastersys dist)

mv /home/remastersys/remastersys/custom.iso /home/remastersys/remastersys/custom-full.iso



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

apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/devpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/archdevpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/dbgpackages.log

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/archdpgpackages.log

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
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/Purges.log

apt-get autoremove -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/autoremoves.log

#remove the built packages so that the smaller ones can be installed cleanly
REMOVEDBGBUILTPKGS=$(dpkg --get-selections | awk '{print $1}' | grep '\-rbos$'| grep -v rbos-rbos | grep -v menuitems-rbos | grep -v buildcorerevisions-rbos)
apt-get purge $REMOVEDBGBUILTPKGS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/devbuiltpackages.log

#Install the reduced packages
compile_all installsmallpackage 


#Force the current files to be true, if a package build process accidentally added an imported file (by touching the file)
#The cached built deb would accidentally overwrite the latest version, install the built deb with the current files.
dpkg --force-overwrite --force-confmiss --force-confnew -i /srcbuild/buildoutput/rbos-rbos_1-${PACKAGEDATE}_${BUILDARCH}.deb


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
(. /usr/bin/build_vars; . /usr/bin/wlruntime_vars; /opt/sbin/plymouth-set-default-theme spinfinity)
#start the remastersys job
(. /usr/bin/build_vars; remastersys dist)
