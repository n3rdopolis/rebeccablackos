#! /bin/bash
#    Copyright (c) 2012 - 2024 nerdopolis (or n3rdopolis) <bluescreen_avenger@verzion.net>
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

#Require root privlages
if [[ $UID != 0 ]]
then
  echo "Must be run as root."
  exit
fi

shopt -s dotglob

export PACKAGEOPERATIONLOGDIR=/var/log/buildlogs/package_operations

#create folder for install logs
mkdir -p "$PACKAGEOPERATIONLOGDIR"

#Create folder to hold the install logs
mkdir "$PACKAGEOPERATIONLOGDIR"/phase_1


#attempt to prevent packages from prompting for debconf
export DEBIAN_FRONTEND=noninteractive

#Create _apt user that apt drops to to run things as non-root
adduser --no-create-home --disabled-password --system --force-badname _apt

#update the apt cache
rm -rf /var/lib/apt/lists/*
apt-get update
Result=$?
if [[ $Result != 0 ]]
then
 echo "APT source update failed" |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/failedpackages.log
fi

APTFETCHDATESECONDS=$(grep APTFETCHDATESECONDS= /tmp/buildcore_revisions.txt 2>/dev/null | head -1 | sed 's/APTFETCHDATESECONDS=//g')
if [[ -z $APTFETCHDATESECONDS ]]
then
  APTFETCHDATESECONDS=$(date +%s)
fi

APTFETCHDATE=$(date -d @$APTFETCHDATESECONDS -u +%Y%m%dT%H%M%SZ 2>/dev/null)
APTFETCHDATERESULT=$?
if [[ $APTFETCHDATERESULT != 0 ]]
then
  echo "Invalid APTFETCHDATESECONDS set. Falling back"
  APTFETCHDATESECONDS=$(date +%s)
fi
echo -e "\nAPTFETCHDATESECONDS=$APTFETCHDATESECONDS" > /tmp/APTFETCHDATE

#install basic applications that the system needs to get repositories and packages
INSTALLS=($(cat /tmp/BASE_INSTALLS.txt))
apt-get install ${INSTALLS[@]} -y
apt-get dist-upgrade -y --no-install-recommends

#perl outputs complaints if a locale isn't generated
locale-gen C.UTF-8
localedef -i C -f UTF-8 C.UTF-8

#update the dselect database
yes Y | dselect update

#Get the packages that need to be installed, by determining new packages specified, and packages that did not complete.
if [[ -e /tmp/INSTALLS.txt ]]
then
  rm /tmp/INSTALLS.txt
fi
touch /tmp/INSTALLS.txt

if [[ -e /tmp/POSTREMOVES.txt ]]
then
  rm /tmp/POSTREMOVES.txt
fi
touch /tmp/POSTREMOVES.txt

#Set some variables
export DEBIAN_ARCH=$(dpkg --print-architecture)
export DEBIAN_DISTRO=$(awk '{print $1}' /etc/issue)

#Process the install list into INSTALLS.txt
INSTALLS_LIST=$(sed 's/^ *//;s/ *$//' /tmp/INSTALLS_LIST.txt )
INSTALLS_LIST+=$'\n'
echo "$INSTALLS_LIST" | sed 's/::/@/g' | perl -pe 's/\$(\w+)/$ENV{$1}/g' | while read -r LINE
do
  IFS=@
  #Get all the major elements of the line
  LINE=($LINE)
  unset IFS
  UntrueConditionals=0
  CONDITIONAL_STATEMENTS=${LINE[2]}
  

  #Get all the conditionals in the third column of INSTALLS_LIST.txt. If there are none, all are assumed true. They are seperated by commas,
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
  if [[ $UntrueConditionals == 0 && ! -z "${LINE[0]}" ]]
  then
   echo "${LINE[0]}::${LINE[1]}" | grep  -E -v "^#|^$" >> /tmp/INSTALLS.txt
   #If the package is set to be removed after it is used only for building certian packages
   if [[ ${LINE[3]} == "BUILDONLY" ]]
   then
     echo "${LINE[0]}" | grep  -E -v "^#|^$" >> /tmp/POSTREMOVES.txt
   fi
  fi
done

#Ensure that the files that are being created exist
touch /tmp/INSTALLS.txt

#Cleanup INSTALLS files
sed -i 's/^ *//;s/ *$//;/^$/d' /tmp/INSTALLS.txt

#Generate a list of all valid packages off the apt cache into a quickly parseable format, to test if a package name is valid.
apt-cache search . | awk '{print $1}' > /tmp/AVAILABLEPACKAGES.txt

#Get list of new packages to download
INSTALLS="$(cat /tmp/INSTALLS.txt | awk -F "#" '{print $1}' )"

#Clear whitespace
INSTALLS="$(echo "$INSTALLS" | awk ' !x[$0]++')"

#Clear any empty lines
INSTALLS=$(echo -n "$INSTALLS" |sed 's/^ *//;s/ *$//;/^$/d')

#Add a newline, only if there is one or more actual lines
if [[ ! -z $INSTALLS ]]
then
  INSTALLS+=$'\n'
fi

#DOWNLOAD THE PACKAGES SPECIFIED
PART_PACKAGES=""
FULL_PACKAGES=""
while read -r PACKAGEINSTRUCTION
do
  PACKAGE=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $1}' )
  METHOD=$(echo $PACKAGEINSTRUCTION | awk -F "::" '{print $2}' )

  AvailableCount=$(cat /tmp/AVAILABLEPACKAGES.txt | grep -c ^$PACKAGE$)
  if [[ $AvailableCount == 0 ]]
  then
    Result=1
  else
    Result=0
  fi

  #Partial install
  if [[ $METHOD == "PART" ]]
  then
    if [[ $Result == 0 ]]
    then
      echo "Downloading with partial dependancies for $PACKAGE"                     > "$PACKAGEOPERATIONLOGDIR"/phase_1/0_PART_Downloads.log
      PART_PACKAGES+="$PACKAGE "
    fi
  #with all dependancies
  elif [[ $METHOD == "FULL" ]]
  then
    if [[ $Result == 0 ]]
    then
      echo "Downloading with all dependancies for $PACKAGE"                         > "$PACKAGEOPERATIONLOGDIR"/phase_1/1_FULL_Downloads.log
      FULL_PACKAGES+="$PACKAGE "
    fi
  else
    Result=1
    echo "Invalid Install Operation: $METHOD on package $PACKAGE"                   > "$PACKAGEOPERATIONLOGDIR"/phase_1/failed_"$PACKAGE".log
    METHOD="INVALID OPERATION SPECIFIED"
  fi

  #if the install resut for the current package failed, then log it. If it worked, then remove it from the list of unfinished downloads
  if [[ $Result != 0 ]]
  then
    echo "$PACKAGE failed to $METHOD" |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/failedpackages.log
  fi
done < <(echo -n "$INSTALLS")


apt-get --no-install-recommends install $PART_PACKAGES -d -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/0_PART_Downloads.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
  echo "Partial Downloads failed: $PART_PACKAGES" |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/failedpackages.log
fi

apt-get install $FULL_PACKAGES -d -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/1_FULL_Downloads.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
  echo "Full Downloads failed: $FULL_PACKAGES" |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/failedpackages.log
fi

#Download updates
apt-get dist-upgrade -d -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/2_dist-upgrade.log
Result=${PIPESTATUS[0]}
if [[ $Result != 0 ]]
then
  echo "Dist Upgrade failed" |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/failedpackages.log
fi


#Use dselect-upgrade in download only mode to force the downloads of the cached and uninstalled debs in phase 1
if [[ -f /tmp/INSTALLSSTATUS.txt ]]
then
  dpkg --get-selections > /tmp/DOWNLOADSSTATUS.txt
  dpkg --set-selections < /tmp/INSTALLSSTATUS.txt
  apt-get -d -u dselect-upgrade --no-install-recommends -y 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/3_dselect-upgrade.log
  dpkg --clear-selections
  dpkg --set-selections < /tmp/DOWNLOADSSTATUS.txt
fi

#Remove packages that can no longer be downloaded to preserve space
ESSENTIALOBSOLETEPACKAGECOUNT=$(aptitude search '~o~E' |wc -l)
if [[ $ESSENTIALOBSOLETEPACKAGECOUNT == 0 && ! -e /tmp/buildcore_revisions.txt ]]
then
  apt-get autoclean -o APT::Clean-Installed=off 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/4_purge_obsolete.log
else
  echo "Not purging older packages, because apt-get update failed, or building from a Debian snapshot" 2>&1 |tee -a "$PACKAGEOPERATIONLOGDIR"/phase_1/4_purge_obsolete.log
fi


#run the script that calls all compile scripts in a specified order, in download only mode
compile_all download-only
