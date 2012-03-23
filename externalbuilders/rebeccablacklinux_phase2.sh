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
mkdir ~/RBOS_Build_Files/build_mountpoint

#mount the image created above at the mountpoint as a loop device
mount ~/RBOS_Build_Files/RBOS_FS.img ~/RBOS_Build_Files/build_mountpoint -o loop,compress-force=lzo



#copy in the files needed
rsync "$ThIsScriPtSFolDerLoCaTion"/../rebeccablacklinux_files/* -Cr ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/


#make the imported files executable 
chmod +x -R ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/
chown  root  -R ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/
chgrp  root  -R ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/


#copy the new translated executable files to where they belong
rsync ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/* -a ~/RBOS_Build_Files/build_mountpoint/phase_1/

#delete the temp folder
rm -rf ~/RBOS_Build_Files/build_mountpoint/phase_1/temp/



#mounting devfs on chrooted fs with bind 
mount --bind /dev ~/RBOS_Build_Files/build_mountpoint/phase_2/dev/


#Configure the Live system########################################
chroot ~/RBOS_Build_Files/build_mountpoint/phase_2 /tmp/configure_phase2.sh



#delete the old copy of the ISO 
rm ~/RebeccaBlackLinux.iso
#move the iso out of the chroot fs    
cp ~/RBOS_Build_Files/build_mountpoint/phase_2/home/remastersys/remastersys/custom.iso ~/RebeccaBlackLinux.iso

#allow the user to actually read the iso   
chown $USER ~/RebeccaBlackLinux.iso
chgrp $USER ~/RebeccaBlackLinux.iso
chmod 777 ~/RebeccaBlackLinux.iso


#go back to the users home folder
cd ~


#unmount the chrooted procfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/proc

#unmount the chrooted sysfs from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/sys

#unmount the chrooted dev/pts from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/dev/pts

#unmount the chrooted dev/shm from the outside
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/dev/shm

#unmount the chrooted devfs from the outside 
umount -lf ~/RBOS_Build_Files/build_mountpoint/phase_2/dev

#kill any process accessing the livedisk mountpoint 
fuser -k ~/RBOS_Build_Files/build_mountpoint 

#Delete Phase 2 snapshot
btrfs subvolume delete ~/RBOS_Build_Files/build_mountpoint/phase_2

#unmount the chroot fs
umount -lfd ~/RBOS_Build_Files/build_mountpoint






#If the live cd did not build then tell user  
if [ ! -f ~/RebeccaBlackLinux.iso ];
then  
echo "The Live CD did not succesfuly build. if you did not edit this script please make sure you are conneced to 'the Internet', and be able to reach the Ubuntu archives, and Remastersys's archives and try agian. if you did edit it, check your syntax"
exit 1
fi 

#If the live cd did  build then tell user   
if [  -f ~/RebeccaBlackLinux.iso ];
then  
echo "Live CD image build was successful. It was created at ${HOME}/RebeccaBlackLinux.iso"
exit 1
fi
