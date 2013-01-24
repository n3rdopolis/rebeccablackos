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

#Copy select files into place, that are suitable for distribution.
mkdir -p /usr/bin
rsync /usr/import/usr/bin/* -a /usr/bin

mkdir -p /usr/libexec
rsync /usr/import/usr/libexec/* -a /usr/libexec

mkdir -p /usr/share/RBOS_MENU
rsync /usr/import/usr/share/RBOS_MENU/* -a /usr/share/RBOS_MENU

mkdir -p /usr/share/RBOS_PATCHES
rsync /usr/import/usr/share/RBOS_PATCHES/* -a /usr/share/RBOS_PATCHES

mkdir -p /usr/share/icons
rsync /usr/import/usr/share/icons/* -a /usr/share/icons

mkdir -p /usr/share/wallpapers/RebeccaBlackOS/
rsync /usr/import/usr/share/wallpapers/RebeccaBlackOS/* -a /usr/share/wallpapers/RebeccaBlackOS/

mkdir -p /etc/skel/.config
rsync /usr/import/etc/skel/.config/* -a /etc/skel/.config

mkdir -p /var
rsync /usr/import/var/* -a /var
#install the menu items for the wayland tests
install_menu_items