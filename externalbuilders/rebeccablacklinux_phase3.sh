#! /usr/bin/sudo /bin/bash
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
echo "PHASE 3"  
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")

HOMELOCATION=~
RBOSLOCATION=~/RBOS_Build_Files
unset HOME

#create a folder for the media mountpoints in the media folder
mkdir $RBOSLOCATION/build_mountpoints
mkdir $RBOSLOCATION/build_mountpoints/phase_1
mkdir $RBOSLOCATION/build_mountpoints/phase_2
mkdir $RBOSLOCATION/build_mountpoints/phase_3
mkdir $RBOSLOCATION/build_mountpoints/buildoutput
mkdir $RBOSLOCATION/build_mountpoints/workdir

#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the FS at the workdir and phase 2
umount -lfd $RBOSLOCATION/build_mountpoints/workdir
umount -lfd $RBOSLOCATION/build_mountpoints/phase_2

#Clean up Phase 3 data.
rm -rf $RBOSLOCATION/build_mountpoints/phase_3/*

#create the union of phases 1, 2, and 3 at workdir
mount -t overlayfs -o lowerdir=$RBOSLOCATION/build_mountpoints/phase_1,upperdir=$RBOSLOCATION/build_mountpoints/phase_2 overlayfs $RBOSLOCATION/build_mountpoints/phase_2
mount -t overlayfs -o lowerdir=$RBOSLOCATION/build_mountpoints/phase_2,upperdir=$RBOSLOCATION/build_mountpoints/phase_3 overlayfs $RBOSLOCATION/build_mountpoints/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev $RBOSLOCATION/build_mountpoints/workdir/dev/
mount --rbind /proc $RBOSLOCATION/build_mountpoints/workdir/proc/
mount --rbind /sys $RBOSLOCATION/build_mountpoints/workdir/sys/

#Mount in the folder with previously built debs
mount --rbind $RBOSLOCATION/build_mountpoints/buildoutput $RBOSLOCATION/build_mountpoints/workdir/srcbuild/buildoutput

#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr $RBOSLOCATION/build_mountpoints/workdir/temp/


#make the imported files executable 
chmod +x -R $RBOSLOCATION/build_mountpoints/workdir/temp/
chown  root  -R $RBOSLOCATION/build_mountpoints/workdir/temp/
chgrp  root  -R $RBOSLOCATION/build_mountpoints/workdir/temp/


#copy the files to where they belong
cp -a $RBOSLOCATION/build_mountpoints/workdir/temp/* $RBOSLOCATION/build_mountpoints/workdir/
cp -a $RBOSLOCATION/build_mountpoints/workdir/temp/* $RBOSLOCATION/build_mountpoints/workdir/usr/import
rm -rf $RBOSLOCATION/build_mountpoints/workdir/usr/import/tmp
rm -rf $RBOSLOCATION/build_mountpoints/workdir/usr/import/usr/import

#delete the temp folder
rm -rf $RBOSLOCATION/build_mountpoints/workdir/temp/


#Configure the Live system########################################
chroot $RBOSLOCATION/build_mountpoints/workdir /tmp/configure_phase3.sh

#If the live cd did not build then tell user  
if [ ! -f $RBOSLOCATION/build_mountpoints/workdir/home/remastersys/remastersys/custom.iso ];
then  
echo "The Live CD did not succesfuly build. if you did not edit this script please make sure you are conneced to 'the Internet', and be able to reach the Ubuntu archives, and Remastersys's archives and try agian. if you did edit it, check your syntax"

fi 

#If the live cd did  build then tell user   
if [  -f $RBOSLOCATION/build_mountpoints/workdir/home/remastersys/remastersys/custom.iso ];
then  
#delete the old copy of the ISO 
rm $HOMELOCATION/RebeccaBlackLinux.iso
#move the iso out of the chroot fs    
mv $RBOSLOCATION/build_mountpoints/phase_3/home/remastersys/remastersys/custom.iso $HOMELOCATION/RebeccaBlackLinux.iso
mv $RBOSLOCATION/build_mountpoints/phase_3/home/remastersys/remastersys/custom-full.iso $HOMELOCATION/RebeccaBlackLinux_Development.iso


#Create a date string for unique log folder names
ENDDATE=$(date +"%Y-%m-%d %H-%M-%S")

#Create a folder for the log files with the date string
mkdir -p "$RBOSLOCATION/logs/$ENDDATE"

#Export the log files to the location
cp -a "$RBOSLOCATION/build_mountpoints/workdir/usr/share/logs/"* "$RBOSLOCATION/logs/$ENDDATE"

#dump out the logged revision numbers to a file
ls "$RBOSLOCATION/build_mountpoints/workdir/usr/share/Buildlog/" | while read FILE 
do  
cat "$RBOSLOCATION/build_mountpoints/workdir/usr/share/Buildlog/$FILE" | grep REVISION 
done > "$RBOSLOCATION/logs/$ENDDATE/BuiltRevisions.log"


echo "Live CD image build was successful. It was created at $HOMELOCATION/RebeccaBlackLinux.iso"

#allow the user to actually read the iso   
chown $SUDO_USER $HOMELOCATION/RebeccaBlackLinux*.iso
chgrp $SUDO_USER $HOMELOCATION/RebeccaBlackLinux*.iso
chmod 777 $HOMELOCATION/RebeccaBlackLinux*.iso

fi


#unmount the chrooted procfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf $RBOSLOCATION/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf $RBOSLOCATION/build_mountpoints/workdir/dev

#unmount the debs data
umount -lf $RBOSLOCATION/build_mountpoints/workdir/srcbuild/buildoutput

#unmount the FS at the workdir, and phase 2
umount -lfd $RBOSLOCATION/build_mountpoints/workdir
umount -lfd $RBOSLOCATION/build_mountpoints/phase_2

#Clean up Phase 3 data.
rm -rf $RBOSLOCATION/build_mountpoints/phase_3/*