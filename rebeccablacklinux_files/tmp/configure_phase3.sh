#! /bin/bash
#    Copyright (c) 2012, nerdopolis (or n3rdopolis) <bluescreen_avenger@version.net>
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


# configure plymouth to use framebuffer
echo FRAMEBUFFER=y > /etc/initramfs-tools/conf.d/splash

#Copy the import files into the system, and create menu items while creating a deb with checkinstall.
cd /tmp
mkdir debian
touch debian/control
#remove any old deb files for this package
rm "/srcbuild/buildoutput/"rbos-rbos_*.deb
checkinstall -y -D --nodoc --dpkgflags=--force-overwrite --install=yes --backup=no --pkgname=rbos-rbos --pkgversion=1 --pkgrelease=$(date +%s)  --maintainer=rbos@rbos --pkgsource=rbos --pkggroup=rbos --requires="subversion,git,bzr,dlocate,checkinstall,zenity,xterm,vpx-tools" /tmp/configure_phase3_helper.sh
cp *.deb "/srcbuild/buildoutput/"
cd $OLDPWD

#copy all files
rsync /usr/import/* -a /

#delete the import folder
rm -r /usr/import

#run the script that calls all compile scripts in a specified order, in build only mode
compile_all build-only

#Edit remastersys to not detect the filesystem. df fails in chroot
sed  -i 's/^DIRTYPE=.*/DIRTYPE=ext4/' /usr/bin/remastersys

#get the installed kernel version in /lib/modules, there is only one installed in this CD, but take the first one by default.
KERNELVERSION=$(basename $(readlink /vmlinuz) |awk -F "-" '{print $2"-"$3"-"$4}')

#This is a kde distro. Force the remastersys script to install kde frontend, as Remastersys detects running process from kde to determine it is a kde distro, but since this is chroot, it's not running
sed -i "s/\"\`ps axf | grep startkde | grep -v grep\`\" != \"\" -o \"\`ps axf | grep kwin | grep -v grep\`\" != \"\"/ 1 /g" /usr/bin/remastersys


#replace all of remastersys's unames with the installed kernel version.
sed -i "s/\`uname -r\`/$KERNELVERSION/g" /usr/bin/remastersys

#make remastersys use xz compression
sed -i 's/SQUASHFSOPTS="/SQUASHFSOPTS="-comp xz/g' /usr/bin/remastersys

#Don't allow remastersys to remove ubiquity!!!
grep -v "remove ubiquity" /usr/bin/remastersys > /usr/bin/remastersys.bak
cat /usr/bin/remastersys.bak > /usr/bin/remastersys
rm /usr/bin/remastersys.bak

#remove the resolv.conf from the list of files in /etc that remastersys deletes, as it's a symlink to a dynamic file. 
sed -i 's/resolv.conf,//g'  /usr/bin/remastersys

#Remastersys deletes the tty startup files, and disables the ttys. Don't allow it to do so
sed -i 's/rm -f \$WORKDIR\/dummysys\/etc\/init\/tty?.conf//g'  /usr/bin/remastersys

#Remastersys now formats the ISO so it can be 'dd'ed onto a flash drive. However it creates a warning that not all BIOSes might like it, and might be what makes the ISO creation phase slower. This feature can be replaced with unetbootin or the USB startup creator, as it is easier for the user as well
grep -v "hybrid" /usr/bin/remastersys > /usr/bin/remastersys.bak
cat /usr/bin/remastersys.bak > /usr/bin/remastersys
rm /usr/bin/remastersys.bak

#save the build date of the CD.
echo "$(date)" > /etc/builddate

#start the remastersys job
remastersys dist
