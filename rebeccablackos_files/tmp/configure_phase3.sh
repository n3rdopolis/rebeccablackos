#! /bin/bash
#    Copyright (c) 2012 - 2022 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

dpkg-divert --local --rename --add /usr/lib/os-release
mv /usr/lib/os-release.rbos /usr/lib/os-release

#ibus workaround
ln -s /usr/share/unicode/ /usr/share/unicode/ucd

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
echo "blacklist bochs_drm"   >> /etc/modprobe.d/wlrootsdrmprime.conf
echo "blacklist vboxvideo"   >> /etc/modprobe.d/wlrootsdrmprime.conf

#Create a default /etc/vconsole.conf for plymouth
echo "XKB_LAYOUT=\"us\"" >> /etc/vconsole.conf
echo "XKB_MODEL=\"pc105\"" >> /etc/vconsole.conf
echo "XKB_VARIANT=\"\"" >> /etc/vconsole.conf
echo "XKB_OPTIONS=\"\"" >> /etc/vconsole.conf


#Create a folder for lightdm, so that casper and ubiquity configure autologin, as waylandloginmanager reads the config files
mkdir /etc/lightdm/

#Create admin groups
addgroup --system lpadmin
addgroup --system sambashare
addgroup --system systemd-journald

if [[ -f /tmp/APTFETCHDATE ]]
then
  PACKAGEDATE=$(cat "/tmp/APTFETCHDATE" | grep -v ^$| awk -F = '{print $2}')
else
  PACKAGEDATE=$(date +%s)
fi

#Create a python path
mkdir -p /opt/lib/$(readlink /usr/bin/python3)/site-packages/

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
/usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="" /tmp/configure_phase3_helper.sh
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


#Redirect grub-install if lupin isn't 1st tier
if [[ ! -e /usr/share/initramfs-tools/hooks/lupin_casper ]]
then
  dpkg-divert --add --rename --divert /usr/sbin/grub-install.real /usr/sbin/grub-install
  echo 'if [ -x /usr/sbin/grub-install.lupin ]; then /usr/sbin/grub-install.lupin "$@"; else /usr/sbin/grub-install.real "$@"; fi; exit $?' > /usr/sbin/grub-install
  chmod +x /usr/sbin/grub-install
fi

#Force CRYPTSETUP to be enabled, so that needed files are already copied
echo "export CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook

#Set default user groups
printf "\nADD_EXTRA_GROUPS=1\nEXTRA_GROUPS="adm plugdev cdrom sudo floppy audio video scanner netdev dip lpadmin sambashare systemd-journald"\n" >> /etc/adduser.conf

#workaround so that all PAM files are stored in the proper place
mkdir -p /opt/etc
ln -s /etc/pam.d /opt/etc/pam.d

#workaround hardcoded links to /usr/bin/python in various scripts
ln -s $(which python3) /usr/bin/python

#Configure a locale so that the initramfs doesn't have to
update-locale LANG=en_US.UTF-8

#Remove the rust lock file from previous builds in case the download process for rust stopped before it completed
if [[ -e /srcbuild/buildhome/buildcore_rust/lockfile ]]
then
  rm /srcbuild/buildhome/buildcore_rust/lockfile &> /dev/null
fi

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Append the snapshot date to the end of the revisions file
cat /tmp/APTFETCHDATE >> /usr/share/buildcore_revisions.txt

#Actions that are performed after all the packages are compiled
function PostInstallActions
{
  #Create a package with all the menu items.
  cd /tmp
  rm "/srcbuild/buildoutput/"menuitems-rbos*.deb
  /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=menuitems-rbos --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos install_menu_items
  cp *.deb "/srcbuild/buildoutput/"
  cd $OLDPWD

  #Set the cursor theme
  update-alternatives --set x-cursor-theme /etc/X11/cursors/oxy-white.theme
  
  #Install any systemd-user sessions from /opt to where systemd can see them
  find /opt/lib/systemd/user/* | while read -r FILE
  do
    ln -s $FILE /usr/lib/systemd/user/
  done

  #configure /etc/issue
  echo -e "RebeccaBlackOS \\\n \\\l \n" > /etc/issue
  setterm -cursor on >> /etc/issue
  echo -e "RebeccaBlackOS \n" > /etc/issue.net

  #configure grub color
  echo "set color_normal=black/black" > /boot/grub/custom.cfg

  #disable services that conflict with the waylandloginmanager
  systemctl disable lightdm.service
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
  systemctl --global enable wireplumber.service
  systemctl --global disable pulseaudio.service
  systemctl --global disable pulseaudio.socket
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
  mkdir -p /usr/share/polkit-1/actions/
  find /opt/share/polkit-1/actions/ -type f | while read -r FILE;
  do
    FILENAME=$(basename $FILE)
    cp "$FILE" /usr/share/polkit-1/actions/$FILENAME
  done

  mkdir -p /usr/share/polkit-1/rules.d/
  find /opt/share/polkit-1/rules.d -type f | while read -r FILE;
  do
    FILENAME=$(basename $FILE)
    ln -s "$FILE" /usr/share/polkit-1/rules.d/$FILENAME
  done

  mkdir -p /usr/share/dbus-1/system-services/
  find /opt/share/dbus-1/system-services/ -type f | while read -r FILE;
  do
    FILENAME=$(basename $FILE)
    ln -s "$FILE" /usr/share/dbus-1/system-services/$FILENAME
  done

  mkdir -p /etc/dbus-1/services/
  find /opt/etc/dbus-1/services/ -type f | while read -r FILE;
  do
    FILENAME=$(basename $FILE)
    ln -s "$FILE" /etc/dbus-1/services/$FILENAME
  done

  mkdir -p /usr/share/dbus-1/system.d/
  find /opt/share/dbus-1/system.d/ -type f | while read -r FILE;
  do
    FILENAME=$(basename $FILE)
    ln -s "$FILE" /usr/share/dbus-1/system.d/$FILENAME
  done

  #ubiquity workaround. XWayland only permits applications that run as the user, so run it as a Wayland cleint
  if [[ -e /usr/bin/ubiquity ]]
  then
    dpkg-divert --add --rename --divert /usr/bin/ubiquity.real /usr/bin/ubiquity
    echo -e "#! /bin/bash\nwlsudo ubiquity.real" > /usr/bin/ubiquity
    chmod +x /usr/bin/ubiquity
  fi

  #Force the current files to be true, if a package build process accidentally added an imported file (by touching the file)
  #The cached built deb would accidentally overwrite the latest version, install the built deb with the current files.
  dpkg --force-overwrite -i /srcbuild/buildoutput/rbos-rbos_1-${PACKAGEDATE}_${BUILDARCH}.deb

  #move the import folder
  mv /usr/import /tmp
  
  #Make the 'hidden' waylandloginmanager zenity to kdialog convert script executable
  chmod 755 /usr/share/RBOS_PATCHES/wlm-zenity-kdialog

  #Force initramfs utilites to include the overlay filesystem
  echo overlay >> /etc/initramfs-tools/modules

  #Create a /opt/var/log folder
  mkdir /opt/var/log

  #Replace X symlink
  dpkg-divert --add --rename --divert /usr/bin/X.distrib /usr/bin/X
  ln -s /opt/bin/Xorg /usr/bin/X
  
  #Replace chvt with the seat aware wrapper
  dpkg-divert --add --rename --divert /usr/bin/chvt.console /usr/bin/chvt 
  ln -s /usr/bin/chvt-ng /usr/bin/chvt

  #save the build date of the CD.
  date -u +"%A, %Y-%m-%d %H:%M:%S %Z" > /etc/builddate
}
PostInstallActions |& tee -a "$PACKAGEOPERATIONLOGDIR"/PostInstallActions.log

#clean apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
rm -rf /var/lib/apt/lists/*
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
REMOVEDBGBUILTPKGS=$(dpkg --get-selections | awk '{print $1}' | grep '\-rbos$'| grep -v rbos-rbos | grep -v menuitems-rbos)
apt-get purge $REMOVEDBGBUILTPKGS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/Removes/devbuiltpackages.log

#Install the reduced packages
compile_all installsmallpackage 


#Force the current files to be true, if a package build process accidentally added an imported file (by touching the file)
#The cached built deb would accidentally overwrite the latest version, install the built deb with the current files.
dpkg --force-overwrite -i /srcbuild/buildoutput/rbos-rbos_1-${PACKAGEDATE}_${BUILDARCH}.deb


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
