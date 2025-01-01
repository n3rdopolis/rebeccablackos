#! /bin/bash
#    Copyright (c) 2012 - 2025 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#Sets color_normal, menu_color_normal, menu_color_highlight with GRUB_COLOR_NORMAL, GRUB_MENU_COLOR_NORMAL, GRUB_MENU_COLOR_HIGHLIGHT from /etc/default/grub or /etc/default/grub.d/*

if [ -e /etc/default/grub ]
then 
  source /etc/default/grub
fi

if [ -d /etc/default/grub.d ]
then
  find -type f /etc/default/grub.d/* | sort | while read -r FILE
  do
    source "$FILE"
  done
fi

if [ ! -z $GRUB_COLOR_NORMAL ]
then
  echo "set color_normal=$GRUB_COLOR_NORMAL"
fi

if [ ! -z $GRUB_MENU_COLOR_NORMAL ]
then
  echo "set menu_color_normal=$GRUB_MENU_COLOR_NORMAL"
fi

if [ ! -z $GRUB_MENU_COLOR_HIGHLIGHT ]
then
  echo "set menu_color_highlight=$GRUB_MENU_COLOR_HIGHLIGHT"
fi
