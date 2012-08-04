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
echo "PHASE 2"  
ThIsScriPtSFiLeLoCaTion=$(readlink -f "$0")
ThIsScriPtSFolDerLoCaTion=$(dirname "$ThIsScriPtSFiLeLoCaTion")



#create a media mountpoint in the media folder
mkdir ~/RBOS_Build_Files/build_mountpoints

#create the file that will be the filesystem image for the second phase
dd if=/dev/zero of=~/RBOS_Build_Files/RBOS_FS_PHASE_2.img bs=1 count=0 seek=8G 


echo "creating a file system on the virtual image. Not on your real file system."
#create a file system on the image 
yes y | mkfs.ext4 ~/RBOS_Build_Files/RBOS_FS_PHASE_2.img



#mount the images for the two FSes
mount ~/RBOS_Build_Files/RBOS_FS_PHASE_1.img ~/RBOS_Build_Files/build_mountpoints/phase_1 -o loop
mount ~/RBOS_Build_Files/RBOS_FS_PHASE_2.img ~/RBOS_Build_Files/build_mountpoints/phase_2 -o loop

#create the union of the two overlay FSes at the workdir
mount -t aufs -o dirs=~/RBOS_Build_Files/build_mountpoints/phase_2:~/RBOS_Build_Files/build_mountpoints/phase_1 none ~/RBOS_Build_Files/build_mountpoints/workdir

#mounting critical fses on chrooted fs with bind 
mount --rbind /dev ~/RBOS_Build_Files/build_mountpoints/workdir/dev/
mount --rbind /proc ~/RBOS_Build_Files/build_mountpoints/workdir/proc/
mount --rbind /sys ~/RBOS_Build_Files/build_mountpoints/workdir/sys/


#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr ~/RBOS_Build_Files/build_mountpoints/workdir/temp/


#make the imported files executable 
chmod +x -R ~/RBOS_Build_Files/build_mountpoints/workdir/temp/
chown  root  -R ~/RBOS_Build_Files/build_mountpoints/workdir/temp/
chgrp  root  -R ~/RBOS_Build_Files/build_mountpoints/workdir/temp/


#copy the files to where they belong
cp -a ~/RBOS_Build_Files/build_mountpoints/workdir/temp/* ~/RBOS_Build_Files/build_mountpoints/workdir/

#delete the temp folder
rm -rf ~/RBOS_Build_Files/build_mountpoints/workdir/temp/



#mounting devfs on chrooted fs with bind 
mount --bind /dev ~/RBOS_Build_Files/build_mountpoints/workdir/dev/


#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoints/workdir /tmp/configure_phase2.sh


#If the live cd did not build then tell user  
if [ ! -f ~/RBOS_Build_Files/build_mountpoints/workdir/home/remastersys/remastersys/custom.iso ];
then  
echo "The Live CD did not succesfuly build. if you did not edit this script please make sure you are conneced to 'the Internet', and be able to reach the Ubuntu archives, and Remastersys's archives and try agian. if you did edit it, check your syntax"

fi 

#If the live cd did  build then tell user   
if [  -f ~/RBOS_Build_Files/build_mountpoints/workdir/home/remastersys/remastersys/custom.iso ];
then  
#delete the old copy of the ISO 
rm ~/RebeccaBlackLinux.iso
#move the iso out of the chroot fs    
cp ~/RBOS_Build_Files/build_mountpoints/workdir/home/remastersys/remastersys/custom.iso ~/RebeccaBlackLinux.iso

#dump out the logged revision numbers to a file
ls ~/RBOS_Build_Files/build_mountpoints/workdir/usr/share/Buildlog/ | while read FILE 
do  
REV=$(cat ~/RBOS_Build_Files/build_mountpoints/workdir/usr/share/Buildlog/$FILE | grep REVISION | awk '{print $2}')
echo $FILE=$REV
done > ~/RBOS_Build_Files/BuiltRevisions-$(date +%s)


echo "Live CD image build was successful. It was created at ${HOME}/RebeccaBlackLinux.iso"

#allow the user to actually read the iso   
chown $SUDO_USER ~/RebeccaBlackLinux.iso
chgrp $SUDO_USER ~/RebeccaBlackLinux.iso
chmod 777 ~/RebeccaBlackLinux.iso

fi


#go back to the users home folder
cd ~


#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/sys

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoints/workdir/dev

#Kill processess accessing the workdir mountpoint
fuser -kmM   ~/RBOS_Build_Files/build_mountpoints/workdir 2> /dev/null

#unmount the FS at the workdir
umount -lfd ~/RBOS_Build_Files/build_mountpoints/workdir

#unmount the underlay filesystems
umount -lfd ~/RBOS_Build_Files/build_mountpoints/phase_1
umount -lfd ~/RBOS_Build_Files/build_mountpoints/phase_2

#Delete the FS image for phase 2.
rm ~/RBOS_Build_Files/RBOS_FS_PHASE_2.img