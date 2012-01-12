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

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#update the apt cache
apt-get update

#install aptitude
echo Y | apt-get install aptitude

#Add Language packs as translations are added
aptitude install language-pack-en --without-recommends -y


#install a kernel for the Live disk
aptitude install linux-generic  --without-recommends -y

#Install Wayland depends 
yes Yes | apt-get install build-essential libtool libxi-dev libxmu-dev libxt-dev bison flex libgl1-mesa-dev xutils-dev libtalloc-dev libdrm-dev autoconf x11proto-kb-dev libegl1-mesa-dev libgles2-mesa-dev libgdk-pixbuf2.0-dev libudev-dev libxcb-dri2-0-dev libxcb-xfixes0-dev shtool libffi-dev libpoppler-glib-dev libgtk2.0-dev git diffstat libx11-xcb-dev quilt autopoint dh-autoreconf xkb-data gtk-doc-tools gobject-introspection gperf librsvg2-bin libpciaccess-dev  python-libxml2 libjpeg-dev   libgbm-dev libxcb-glx0-dev  -y

#install Kubuntu Desktop
yes Yes |apt-get install kubuntu-desktop -y


#install remastersys
yes Yes | aptitude install remastersys -y

#install depends for building QT
yes Yes | aptitude install libxcb1 libxcb1-dev libx11-xcb1 libx11-xcb-dev libxcb-keysyms1 libxcb-keysyms1-dev libxcb-image0 libxcb-image0-dev libxcb-shm0 libxcb-shm0-dev libxcb-icccm4 libxcb-icccm4-dev libxcb-sync0 libxcb-sync0-dev libxcb-xfixes0-dev -y

#Install depends for building xwayland (nested X under Wayland)
yes Yes | aptitude install x11proto-xcmisc-dev   x11proto-bigreqs-dev x11proto-fonts-dev  x11proto-video-dev x11proto-record-dev x11proto-resource-dev libxkbfile-dev libxfont-dev -y
yes Y | apt-get build-dep tinc

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



#set LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH):/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH):/usr/local/lib:/usr/lib

#set to the ld
echo "/usr/local/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)
/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)
/usr/local/lib
/usr/lib
" > /etc/ld.so.conf.d/libc.conf
ldconfig

#Compile software
mkdir /usr/share/buildlog
mkdir /srcbuild
cd /srcbuild
ls /usr/bin/compile/B* | while read BUILDSCRIPT
do
BUILDNAME=$(echo "$BUILDSCRIPT" |rev | awk -F / '{print $1}' | sed 's/....$//' |  rev)
echo "building $BUILDNAME"
"$BUILDSCRIPT" 2>&1 | tee  /usr/share/buildlog/$BUILDNAME
done
cd ..

#configure the xwayland server
mkdir /usr/local/etc/X11
cat > /usr/local/etc/X11/xorg.conf <<EOF
Section "Device"
        Identifier "Device"
        Driver "wlshm" # or intel
EndSection
EOF

#install more Wayland clients into the PATH
find /srcbuild/weston/clients -executable | while read CLIENT
do
cp "$CLIENT" /usr/local/bin
done

#install the clients into libexec as well
mkdir /usr/local/libexec
find /srcbuild/weston/clients -executable | while read CLIENT
do
cp "$CLIENT" /usr/local/libexec
done

#remove the build packages
rm -rf /srcbuild




#Edit remastersys to not detect the filesystem. df fails in chroot
sed  -i 's/^DIRTYPE=.*/DIRTYPE=ext4/' /usr/bin/remastersys

#get the installed kernel version in /lib/modules, there is only one installed in this CD, but take the first one by default.
KERNELVERSION=$(ls /lib/modules/ | head -1 )

#replace all of remastersys's unames with the installed kernel version.
sed -i "s/\`uname -r\`/$KERNELVERSION/g" /usr/bin/remastersys

#start the remastersys job
remastersys dist




