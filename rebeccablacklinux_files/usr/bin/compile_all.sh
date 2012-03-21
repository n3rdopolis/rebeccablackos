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

export LD_LIBRARY_PATH=/opt/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH):/usr/local/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH):/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH):/opt/lib:/usr/local/lib:/usr/lib
export PATH="/opt/sbin:/opt/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/sbin:/bin:/usr/games"

mkdir /usr/share/Buildlog
mkdir /srcbuild

#build these packages in this order. # symbol is a comment
echo "
wayland
drm
macros
glproto
dri2proto
mesa
xproto
kbproto
libX11
libxkbcommon
pixman
cairo
weston
qtbase
qtwayland
#thiago-intels-qt
#extra-cmake-modules
#kdelibs
xserver
xf86-video-wlshm
glib
gtk+
cogl
clutter
eina
eet
evas
ecore
embryo
edje
efreet
e_dbus
eeze
elementary
" | awk -F "#" '{print $1}' | while read BUILDNAME
do
#if it's download only, parse the files for the git and svn repos, and download them.
if [[ $1 == download-only]]
then
mkdir -p /srcbuild/$BUILDNAME





cat "/usr/bin/Compile/$BUILDNAME" | grep GITURLPATH= | while read GITLINE
do
GITURL=$(echo $GITLINE | awk -F 'GITURLPATH=' '{print $2}')
git clone $GITURL
cd $BUILDNAME
GITREVISION=$(cat "/usr/bin/Compile/$BUILDNAME" | grep GITREVISION= | awk -F '=' '{print $2}' | head -1)
git checkout $GITREVISION
git pull
cd /srcbuild
done

cat "/usr/bin/Compile/$BUILDNAME" | grep SVNURLPATH= | while read SVNLINE
do
SVNURL=$(echo $SVNLINE | awk -F 'SVNURLPATH=' '{print $2}')
svn co $SVNURL
cd $BUILDNAME
SVNREVISION=$(cat "/usr/bin/Compile/$BUILDNAME" | grep SVNREVISION= | awk -F '=' '{print $2}' | head -1)
svn merge -r HEAD:$SVNREVISION $SVNURL
svn update 
cd /srcbuild
done





#srcbuild is not running as a downloader
else
echo "building $BUILDNAME"
"/usr/bin/Compile/$BUILDNAME" 2>&1 | tee  /usr/share/Buildlog/$BUILDNAME
/srcbuild
fi

done

#remove the build packages
rm -rf /srcbuild