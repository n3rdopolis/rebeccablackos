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


#mount the procfs
mount -t proc none /proc


#mount sysfs
mount -t sysfs none /sys



#mount /dev/pts
mount -t devpts none /dev/pts


#update the apt cache
apt-get update

#install aptitude
echo Y | apt-get install aptitude

#Add Language packs as translations are added
aptitude install language-pack-en --without-recommends -y


#install a kernel for the Live disk
aptitude install linux-generic  --without-recommends -y

#Install Wayland depends 
yes Yes | apt-get install build-essential libtool libxi-dev libxmu-dev libxt-dev bison flex libgl1-mesa-dev xutils-dev libtalloc-dev libdrm-dev autoconf x11proto-kb-dev libegl1-mesa-dev libgles2-mesa-dev libgdk-pixbuf2.0-dev libudev-dev libxcb-dri2-0-dev libxcb-xfixes0-dev shtool libffi-dev libpoppler-glib-dev libgtk2.0-dev git diffstat libx11-xcb-dev quilt autopoint dh-autoreconf xkb-data gtk-doc-tools gobject-introspection gperf librsvg2-bin libpciaccess-dev  python-libxml2 libjpeg-dev   libgbm-dev libjpeg-turbo62     libjpeg-turbo-progs    -y

#install Kubuntu Desktop
yes Yes |apt-get install kubuntu-desktop -y

#install a plymouth theme 
yes Yes | aptitude install plymouth-theme-spinfinity  --without-recommends -y

#install remastersys
yes Yes | aptitude install remastersys -y
##################################################################################################################




#For some reason, it installs out of date packages sometimes, as I see unupgraded packages
yes Y | apt-get dist-upgrade

#Do this as some packages fail to install completly unless if the attempt to start them as deamons succeeds. This will report success during those attempts to start the services to dpkg
mv /sbin/initctl /sbin/initctl.bak
ln -s /bin/true /sbin/initctl
yes Y | apt-get dist-upgrade
rm /sbin/initctl
mv  /sbin/initctl.bak /sbin/initctl

#copy all the post install files
rsync /usr/import/* -a /


# /lib/plymouth/ubuntu-logo.png
echo FRAMEBUFFER=y > /etc/initramfs-tools/conf.d/splash
echo 2 | update-alternatives --config default.plymouth





###BEGIN REMASTERSYS EDITS####
#edit the remastersys script file so that it updates the initramfs instead of making a new one with uname -r as it doesnt work in chroot
sed -i -e ' /# Step 6 - Make filesystem.squashfs/ a update-initramfs -u  ' /usr/bin/remastersys 
#copy the initramfs to the correct location
sed -i -e ' /update-initramfs/ a cp /initrd.img \$WORKDIR/ISOTMP/casper/initrd.gz ' /usr/bin/remastersys 
###END REMASTERSYS EDITS





#Compile software
mkdir /srcbuild
cd /srcbuild
ls "/usr/bin/compile/B*" | while read BUILDSCRIPT
do
"$BUILDSCRIPT"
done
cd ..
rm -rf /srcbuild

#install more Wayland clients into the PATH
find /srcbuild/wayland-demos/clients -executable | while read CLIENT
do
cp "$CLIENT" /usr/bin
done



#start the remastersys job
remastersys backup




