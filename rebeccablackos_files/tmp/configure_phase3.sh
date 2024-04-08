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

export PACKAGESUFFIX="rbos"

shopt -s dotglob

export PACKAGEOPERATIONLOGDIR=/var/log/buildlogs/package_operations

#Create a log folder for the package operations
mkdir "$PACKAGEOPERATIONLOGDIR"/phase_3

#Create a log folder for non-buildcore built packages
mkdir "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages

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
rm "/var/cache/srcbuild/buildoutput/"${PACKAGESUFFIX}-${PACKAGESUFFIX}_*.deb
env -C /tmp/mainpackage/ -- /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=${PACKAGESUFFIX}-${PACKAGESUFFIX} --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=${PACKAGESUFFIX}@${PACKAGESUFFIX} --pkgsource=${PACKAGESUFFIX} --pkggroup=${PACKAGESUFFIX} --requires="" --exclude=/var/cache/srcbuild,/home/remastersys,/var/tmp,/var/log/buildlogs /tmp/mainpackage/build-package |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/${PACKAGESUFFIX}-${PACKAGESUFFIX}.log
cp /tmp/mainpackage/${PACKAGESUFFIX}-${PACKAGESUFFIX}*.deb "/var/cache/srcbuild/buildoutput/"

#Create a virtual configuration package for the waylandloginmanager
export DEBIAN_FRONTEND=noninteractive
mkdir -p /tmp/wlm-virtualpackage                                                                                            |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
chmod +x /tmp/wlm-virtualpackage/config                                                                                     |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
chmod +x /tmp/wlm-virtualpackage/postinst                                                                                   |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
env -C /tmp/wlm-virtualpackage -- tar czf control.tar.gz control config templates postinst                                  |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
env -C /tmp/wlm-virtualpackage -- tar czf data.tar.gz -T /dev/null                                                          |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
env -C /tmp/wlm-virtualpackage -- ar q waylandloginmanager-${PACKAGESUFFIX}.deb debian-binary                               |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
env -C /tmp/wlm-virtualpackage -- ar q waylandloginmanager-${PACKAGESUFFIX}.deb control.tar.gz                              |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
env -C /tmp/wlm-virtualpackage -- ar q waylandloginmanager-${PACKAGESUFFIX}.deb data.tar.gz                                 |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log
dpkg --force-overwrite --force-confmiss --force-confnew -i /tmp/wlm-virtualpackage/waylandloginmanager-${PACKAGESUFFIX}.deb |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/waylandloginmanager.log

#Don't run ssh by default
systemctl disable ssh.service

#Configure a locale so that the initramfs doesn't have to
update-locale LANG=C.UTF-8

#Remove the rust lock file from previous builds in case the download process for rust stopped before it completed
if [[ -e /var/cache/srcbuild/buildhome/buildcore_rust/lockfile ]]
then
  rm /var/cache/srcbuild/buildhome/buildcore_rust/lockfile &> /dev/null
fi

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Append the snapshot date to the end of the revisions file
cat /tmp/APTFETCHDATE >> /usr/share/buildcore_revisions.txt

#Create a package with all the post install actions, including generating the menu items.
rm "/var/cache/srcbuild/buildoutput/"postbuildcore-${PACKAGESUFFIX}*.deb
env -C /tmp/postbuildcorepackage -- /usr/import/usr/libexec/build_core/checkinstall -y -D --fstrans=no --nodoc --dpkgflags="--force-overwrite --force-confmiss --force-confnew" --install=yes --backup=no --pkgname=postbuildcore-${PACKAGESUFFIX} --pkgversion=1 --pkgrelease=$PACKAGEDATE  --maintainer=${PACKAGESUFFIX}@${PACKAGESUFFIX} --pkgsource=${PACKAGESUFFIX} --pkggroup=${PACKAGESUFFIX} /tmp/postbuildcorepackage/build-package |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/build_packages/postbuildcore-${PACKAGESUFFIX}.log
cp /tmp/postbuildcorepackage/postbuildcore-${PACKAGESUFFIX}*.deb "/var/cache/srcbuild/buildoutput/"

#clean apt stuff
apt-get clean
rm -rf /var/cache/apt-xapian-index/*
find /var/lib/apt/lists ! -type d -delete
rm -rf /var/lib/dlocate/*

#start the remastersys job
remastersys dist
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

apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/0_devpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dev:"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/1_archdevpackages.log


REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg$"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/2_dbgpackages.log

REMOVEDEVPGKS=$(dpkg --get-selections | awk '{print $1}' | grep "\-dbg:"  | grep -v dpkg-dev)
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/3_archdpgpackages.log

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
apt-get purge $REMOVEDEVPGKS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/4_Purges.log

apt-get autoremove -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/5_autoremoves.log

#remove the built packages so that the smaller ones can be installed cleanly
REMOVEDBGBUILTPKGS=$(dpkg --get-selections | awk '{print $1}' | grep -- "-${PACKAGESUFFIX}$"| grep -v ${PACKAGESUFFIX}-${PACKAGESUFFIX} | grep -v postbuildcore-${PACKAGESUFFIX})
apt-get purge $REMOVEDBGBUILTPKGS -y |& tee -a "$PACKAGEOPERATIONLOGDIR"/phase_3/6_devbuiltpackages.log

#Install the reduced packages
compile_all installsmallpackage 

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
remastersys dist
mv /home/remastersys/remastersys/custom.iso /home/remastersys/custom.iso
rm -rf /home/remastersys/remastersys/*

cp /usr/share/buildcore_revisions.txt /home/remastersys/
