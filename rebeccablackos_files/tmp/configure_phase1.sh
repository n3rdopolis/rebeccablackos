#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#Create the correct /etc/resolv.conf symlink
ln -s ../run/resolvconf/resolv.conf /etc/resolv.conf 

#update the apt cache
rm -rf /var/lib/apt/lists/*
apt-get update

#install basic applications that the system needs to get repositories and packages
apt-get install aptitude git bzr subversion mercurial wget dselect locales -y --force-yes 

#perl outputs complaints if a locale isn't generated
locale-gen en_US.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

#update the dselect database
yes Y | dselect update

#create folder for install logs
mkdir -p /usr/share/logs/package_operations

#clean up possible older logs
rm -r /usr/share/logs/package_operations/Downloads

#Create folder to hold the install logs
mkdir /usr/share/logs/package_operations/Downloads

#Get the packages that need to be installed, by determining new packages specified, and packages that did not complete.
rm /tmp/INSTALLS.txt
sed -i 's/^ *//;s/ *$//' /tmp/FAILEDDOWNLOADS.txt

#Set some variables
export DEBIAN_ARCH=$(dpkg --print-architecture)
export DEBIAN_DISTRO=$(awk '{print $1}' /etc/issue)

#Process the install list into INSTALLS.txt
INSTALLS_LIST=$(sed 's/^ *//;s/ *$//' /tmp/INSTALLS_LIST.txt )
INSTALLS_LIST+=$'\n'
echo "$INSTALLS_LIST" | sed 's/::/@/g' | perl -pe 's/\$(\w+)/$ENV{$1}/g' | while read LINE
do
  IFS=@
  #Get all the major elements of the line
  LINE=($LINE)
  unset IFS
  UntrueConditionals=0
  CONDITIONAL_STATEMENTS=${LINE[2]}

  #Get all the conditionals in the third collumn of INSTALLS_LIST.txt. If there are none, all are assumed true. They are seperated by commas,
  IFS=,
  CONDITIONAL_STATEMENTS=($CONDITIONAL_STATEMENTS)
  unset IFS

  #conditionals. == for is, and != for is not. 
  #Usable variables are $DEBIAN_DISTRO and $DEBIAN_ARCH
  for (( Iterator = 0; Iterator < ${#CONDITIONAL_STATEMENTS[@]}; Iterator++ ))
  do
    CONDITIONAL=(${CONDITIONAL_STATEMENTS[$Iterator]})
    OPERAND=${CONDITIONAL[1]}

    if [[ $OPERAND == "==" && ${CONDITIONAL[0]} != ${CONDITIONAL[2]} ]]
    then
      ((UntrueConditionals++))
    fi

    if [[ $OPERAND == "!=" && ${CONDITIONAL[0]} == ${CONDITIONAL[2]} ]]
    then
      ((UntrueConditionals++))
    fi
  done

  #If all conditionals are true
  if [[ $UntrueConditionals == 0 && ! -z "${LINE[0]}" && ! -z "${LINE[1]}" ]]
  then
   echo "${LINE[0]}::${LINE[1]}" >> /tmp/INSTALLS.txt
  fi
done

sed -i 's/^ *//;s/ *$//' /tmp/INSTALLS.txt
sed -i 's/^ *//;s/ *$//' /tmp/INSTALLS.txt.downloadbak
touch /tmp/FAILEDDOWNLOADS.txt
INSTALLS="$(diff -u -N -w1000 /tmp/INSTALLS.txt.downloadbak /tmp/INSTALLS.txt | grep ^+ | grep -v +++ | cut -c 2- | awk -F "#" '{print $1}' | tee -a /tmp/FAILEDDOWNLOADS.txt )"
INSTALLS+="$(echo; diff -u10000 -w1000 -N /tmp/INSTALLS.txt /tmp/FAILEDDOWNLOADS.txt | grep "^ " | cut -c 2- )"
INSTALLS="$(echo "$INSTALLS" | awk ' !x[$0]++')"
INSTALLS+=$'\n'

#DOWNLOAD THE PACKAGES SPECIFIED
while read PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )
  #Partial install
  if [[ $METHOD == "PART" ]]
  then
    echo "Downloading with partial dependancies for $PACKAGE"                       2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    apt-get --no-install-recommends install $PACKAGE -d -y --force-yes    2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
  #with all dependancies
  elif [[ $METHOD == "FULL" ]]
  then
    echo "Downloading with all dependancies for $PACKAGE"                           2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    apt-get install $PACKAGE -d -y --force-yes                            2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
  #builddep
  elif [[ $METHOD == "BUILDDEP" ]]
  then
    echo "Downloading build dependancies for $PACKAGE"                              2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    apt-get build-dep $PACKAGE -d -y --force-yes                            2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log 
    Result=${PIPESTATUS[0]}
  else
    echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   2>&1 |tee -a /usr/share/logs/package_operations/Downloads/"$PACKAGE".log
    Result=1
    METHOD="INVALID OPERATION SPECIFIED"
  fi

  #if the install resut for the current package failed, then log it. If it worked, then remove it from the list of unfinished downloads
  if [[ $Result != 0 ]]
  then
    echo "$PACKAGE failed to $METHOD" |tee -a /usr/share/logs/package_operations/Downloads/failedpackages.log
  else
    echo "$PACKAGE successfully $METHOD"
    grep -v "$PACKAGEINSTRUCTION" /tmp/FAILEDDOWNLOADS.txt > /tmp/FAILEDDOWNLOADS.txt.bak
    cat /tmp/FAILEDDOWNLOADS.txt.bak > /tmp/FAILEDDOWNLOADS.txt
    rm /tmp/FAILEDDOWNLOADS.txt.bak
  fi
done < <(echo "$INSTALLS")

#Save the INSTALLS.txt so that it can be compared with the next run
cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.downloadbak

#Download updates
apt-get dist-upgrade -d -y --force-yes					2>&1 |tee -a /usr/share/logs/package_operations/Downloads/dist-upgrade.log
    
#Use dselect-upgrade in download only mode to force the downloads of the cached and uninstalled debs in phase 1
dpkg --get-selections > /tmp/DOWNLOADSSTATUS.txt
dpkg --set-selections < /tmp/INSTALLSSTATUS.txt
apt-get -d -u dselect-upgrade --no-install-recommends -y --force-yes 	2>&1 |tee -a /usr/share/logs/package_operations/Downloads/dselect-upgrade.log
dpkg --clear-selections
dpkg --set-selections < /tmp/DOWNLOADSSTATUS.txt

#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only