#!/bin/bash

DPKG_ARCH=$(dpkg --print-architecture);

function checkPackageIsInstalled(){
  echo "Checking package is present: $1";
  local packagePresent;
  packagePresent=$(dpkg -l | awk '{print $2}' | grep -c '^$1\(:$DPKG_ARCH\)*');
  if [ "x$packagePresent" == "x0" ]; then
    return 0;
  fi
  return 1;
}

function installPackageIfMissing(){
  checkPackageIsInstalled "$1"
  local packagePresent=$?;
  if [ "x$packagePresent" == "x0" ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "$1"  
  fi
}
function checkPrerequisites(){
  echo "Check prerequisites for $1";
  declare -a packagesToCheck=( "${!1}" )
  for package in  "${packagesToCheck[@]}"
  do
    installPackageIfMissing "$package"    
  done
}

