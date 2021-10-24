#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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
#Make any initramfs script executable
chmod -R +x /usr/import/usr/share/initramfs-tools/

mkdir -p /usr/bin
cp -a /usr/import/usr/bin/* /usr/bin

mkdir -p /usr/libexec
cp -a /usr/import/usr/libexec/* /usr/libexec

mkdir -p /usr/share/
cp -a /usr/import/usr/share/* /usr/share

mkdir -p /etc/skel/.config
cp -a /usr/import/etc/skel/* /etc/skel

mkdir -p /etc/skel/Desktop

mkdir -p /etc/loginmanagerdisplay
cp -a /usr/import/etc/loginmanagerdisplay/* /etc/loginmanagerdisplay

#Make the wlprofile executable
chmod +x /etc/skel/.local/wlprofile

#Make the wsession files executable
chmod +x /usr/share/wsessions.d/*.desktop

#Configure python to use modules in /opt
echo "/opt/lib/python2.7/site-packages" > "/usr/lib/python2.7/dist-packages/optpkgs.pth"
PYTHON3DIRS=$(find /usr/lib/python3* -maxdepth 0 -printf "%f\n")
for PYTHON3DIR in $PYTHON3DIRS
do
echo "/opt/lib/$PYTHON3DIR/site-packages" >> "/usr/lib/python3/dist-packages/optpkgs.pth"
done
