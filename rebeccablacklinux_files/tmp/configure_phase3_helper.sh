#! /bin/bash
#    Copyright (c) 2012, 2013, 2014 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#This file is used by checkinstall for creating the rbos-rbos package that has all of the installed SVN files

#Copy select files into place, that are suitable for distribution.
mkdir -p /usr/bin
cp -a /usr/import/usr/bin/* /usr/bin

mkdir -p /usr/libexec
cp -a /usr/import/usr/libexec/* /usr/libexec

mkdir -p /usr/share/RBOS_MENU
cp -a /usr/import/usr/share/RBOS_MENU/* /usr/share/RBOS_MENU

mkdir -p /usr/share/RBOS_PATCHES
cp -a /usr/import/usr/share/RBOS_PATCHES/* /usr/share/RBOS_PATCHES

mkdir -p /usr/share/icons
cp -a /usr/import/usr/share/icons/* /usr/share/icons

mkdir -p /usr/share/xsessions
cp -a /usr/import/usr/share/xsessions/* /usr/share/xsessions

mkdir -p /usr/share/wallpapers/RebeccaBlackOS/
cp -a /usr/import/usr/share/wallpapers/RebeccaBlackOS/* /usr/share/wallpapers/RebeccaBlackOS

mkdir -p /etc/skel/.config
cp -a /usr/import/etc/skel/* /etc/skel

mkdir -p /root
cp -a /usr/import/root/* /etc/skel/root

mkdir -p /lib
cp -a /usr/import/lib/* /lib

mkdir -p /etc/loginmanagerdisplay
cp -a /usr/import/etc/loginmanagerdisplay/* /etc/loginmanagerdisplay

mkdir -p /etc/dbus-1
cp -a /usr/import/etc/dbus-1/* /etc/dbus-1

#install the menu items for the wayland applications
install_menu_items