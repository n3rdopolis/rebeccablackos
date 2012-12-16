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

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#update the apt cache
apt-get update

#install remastersys key
wget -O - http://www.remastersys.com/ubuntu/remastersys.gpg.key | apt-key add -

#install aptitude
yes Y| apt-get install aptitude git bzr subversion


#LIST OF PACKAGES TO GET INSTALLED
BINARYINSTALLS="$(cat /tmp/BINARYINSTALLS.txt)"

#LIST OF PACKAGES THAT NEED BUILD DEPS
BUILDINSTALLS="$(cat /tmp/BUILDINSTALLS.txt)"

#DOWNLOAD THE PACKAGES SPECIFIED
echo "$BINARYINSTALLS" | while read PACKAGEINSTRUCTION
do
PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F ":" '{print $1}' )
METHOD=$(echo $PACKAGEINSTRUCTION | awk -F ":" '{print $2}' )

if [[ $METHOD == "PART" ]]
then
yes Yes | apt-get --no-install-recommends install $PACKAGE -d -y --force-yes
else
yes Yes | apt-get install $PACKAGE -d -y --force-yes
fi

done



#GET BUILDDEPS FOR THE PACKAGES SPECIFIED
echo "$BUILDINSTALLS" | while read PACKAGE
do
yes Y | apt-get build-dep $PACKAGE -d -y --force-yes
done




#remastersys doesn't put in tmp into the live cds. symlink srcbuild into tmp, so that it can be unlinked from root, and the cmake uninstaller will still exist for the second image
mkdir /tmp/srcbuild
ln -s /tmp/srcbuild /srcbuild 

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only