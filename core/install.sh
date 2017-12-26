#!/bin/bash

. ./common.sh


MODULES=(
"module-helloworld"
"mawk"
"sed"
"screen"
"zip" 
"gzip"
"bzip2"
"mc"
"vim"
"iptables"
"software-properties-common"
"vsftpd"
"nginx"
"php"
"mariadb"
"ca-certificates-java"
"oracle-jdk8" 
"tomcat8"
"jenkins"
)

function setupModule(){
  local module="$1"
  echo "------------------"
  echo "Setting up $module"
  echo "------------------"
  if [ -d "$module" ]; then
    if [ -f "$module/setup-$module.sh" ]; then
      bash "$module/setup-$module.sh"
      return;
    else
      echo "Module $module setup script not found"      
    fi
  else
    echo "Module $module dir not found"
  fi
  echo "Installing package with default settings"
  installPackageIfMissing "$module"
}

function checkInstallPrerequisites(){
  if [ "x$SETUPDATAFILE_REMOTE" != "x" ] && [ ! -f "$SETUPDATAFILE_REMOTE" ]; then
    echo "Unable to find $SETUPDATAFILE_REMOTE file. Quitting installation"
    exit
  fi
  setupModule "jq"
  setupModule "gpg"
}



function installModules(){
  for module in "${MODULES[@]}" 
  do 
    setupModule "$module"
  done
}

checkInstallPrerequisites
installModules
df -h