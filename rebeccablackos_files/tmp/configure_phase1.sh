#! /bin/bash
#    Copyright (c) 2012, 2013, 2014, 2015, 2016, 2017, 2018 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

export PACKAGEOPERATIONLOGDIR=/buildlogs/package_operations

#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#Create _apt user that apt drops to to run things as non-root
adduser --no-create-home --disabled-password --system --force-badname _apt

#update the apt cache
rm -rf /var/lib/apt/lists/*
apt-get update
APTFETCHDATE=$(grep APTFETCHDATE= /tmp/buildcore_revisions.txt 2>/dev/null | head -1 | sed 's/APTFETCHDATE=//g')
if [[ -z $APTFETCHDATE ]]
then
  APTFETCHDATE=$(date -u +%Y%m%dT%H%M%SZ)
fi
echo -e "\nAPTFETCHDATE=$APTFETCHDATE" > /tmp/APTFETCHDATE

#install basic applications that the system needs to get repositories and packages
apt-get install aptitude git bzr subversion mercurial wget rustc curl dselect locales acl sudo -y

#perl outputs complaints if a locale isn't generated
locale-gen en_US.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

#update the dselect database
yes Y | dselect update


#create folder for install logs
mkdir -p "$PACKAGEOPERATIONLOGDIR"

#Create folder to hold the install logs
mkdir "$PACKAGEOPERATIONLOGDIR"/Downloads

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
   echo "${LINE[0]}::${LINE[1]}" | grep  -E -v "^#|^$" >> /tmp/INSTALLS.txt
  fi
done

#Ensure that the files that are being created exist
touch /tmp/FAILEDDOWNLOADS.txt
touch /tmp/INSTALLS.txt
touch /tmp/INSTALLS.txt.downloadbak

#Cleanup INSTALLS files
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/FAILEDDOWNLOADS.txt
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/INSTALLS.txt
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/INSTALLS.txt.downloadbak


#Get list of new packages to download, compared from the previous run
INSTALLS="$(grep -Fxv -f /tmp/INSTALLS.txt.downloadbak /tmp/INSTALLS.txt | awk -F "#" '{print $1}' )"
INSTALLS_FAILAPPEND="$INSTALLS"

#Add the FAILEDDOWNLOADS.txt contents to the installs list, insure that the failed package is still set to be installed by INSTALLS_LIST.txt
INSTALLS+="
$(grep -Fx -f /tmp/INSTALLS.txt /tmp/FAILEDDOWNLOADS.txt )"

#log new packages to FAILEDDOWNLOADS.txt, which will then be removed once the download is successful
echo "$INSTALLS_FAILAPPEND" >> /tmp/FAILEDDOWNLOADS.txt

#Clear whitespace
INSTALLS="$(echo "$INSTALLS" | awk ' !x[$0]++')"

#Clear any empty lines
INSTALLS=$(echo -n "$INSTALLS" |sed 's/^ *//;s/ *$//;/^::$/d;/^$/d')

#Add a newline, only if there is one or more actual lines
if [[ ! -z $INSTALLS ]]
then
  INSTALLS+=$'\n'
fi

#DOWNLOAD THE PACKAGES SPECIFIED
while read PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )
  #Partial install
  if [[ $METHOD == "PART" ]]
  then
    echo "Downloading with partial dependancies for $PACKAGE"                       2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/"$PACKAGE".log
    apt-get --no-install-recommends install $PACKAGE -d -y    2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
  #with all dependancies
  elif [[ $METHOD == "FULL" ]]
  then
    echo "Downloading with all dependancies for $PACKAGE"                           2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/"$PACKAGE".log
    apt-get install $PACKAGE -d -y                           2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/"$PACKAGE".log
    Result=${PIPESTATUS[0]}
  else
    echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/"$PACKAGE".log
    Result=1
    METHOD="INVALID OPERATION SPECIFIED"
  fi

  #if the install resut for the current package failed, then log it. If it worked, then remove it from the list of unfinished downloads
  if [[ $Result != 0 ]]
  then
    echo "$PACKAGE failed to $METHOD" |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/failedpackages.log
  else
    echo "$PACKAGE successfully $METHOD"
    grep -v "$PACKAGEINSTRUCTION" /tmp/FAILEDDOWNLOADS.txt > /tmp/FAILEDDOWNLOADS.txt.bak
    cat /tmp/FAILEDDOWNLOADS.txt.bak > /tmp/FAILEDDOWNLOADS.txt
    rm /tmp/FAILEDDOWNLOADS.txt.bak
  fi
done < <(echo -n "$INSTALLS")

#Save the INSTALLS.txt so that it can be compared with the next run
cp /tmp/INSTALLS.txt /tmp/INSTALLS.txt.downloadbak

#Download updates
apt-get dist-upgrade -d -y                                              2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/dist-upgrade.log
    
#Use dselect-upgrade in download only mode to force the downloads of the cached and uninstalled debs in phase 1
if [[ -f /tmp/INSTALLSSTATUS.txt ]]
then
  dpkg --get-selections > /tmp/DOWNLOADSSTATUS.txt
  dpkg --set-selections < /tmp/INSTALLSSTATUS.txt
  apt-get -d -u dselect-upgrade --no-install-recommends -y                2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/dselect-upgrade.log
  dpkg --clear-selections
  dpkg --set-selections < /tmp/DOWNLOADSSTATUS.txt
fi

#Remove packages that can no longer be downloaded to preserve space
ESSENTIALOBSOLETEPACKAGECOUNT=$(aptitude search '~o~E' |wc -l)
if [[ $ESSENTIALOBSOLETEPACKAGECOUNT == 0 && ! -e /tmp/buildcore_revisions.txt ]]
then
  apt-get autoclean -o APT::Clean-Installed=off                          2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/purge_obsolete.log
else
  echo "Not purging older packages, because apt-get update failed, or building from a Debian snapshot"       2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/Downloads/purge_obsolete.log
fi


#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only
