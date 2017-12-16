#!/bin/bash

ESSENTIALS=(
"mkdir"
"rm"
"chmod"
"touch"
"bash"
"uname"
"grep"
"dpkg"
"getent"
"whoami"
"apt-get"
"cat" 
"gzip" 
"base64"
"tee" 
"su"
"basename"
"df"
)
ROOTESSENTIALS=(
"chpasswd"
"useradd"
)
NONROOTUSER="softsilesia"
BITBUCKET_REPO=https://github.com/gkkulik/softsilesia.git

function checkEssentials(){
  echo "Check essentials: ${ESSENTIALS[@]}" 
  for tool in "${ESSENTIALS[@]}"  
  do
    local isToolPresent;
    isToolPresent=$(which "$tool")
    if [ "x$isToolPresent" == "x" ]; then
      echo "Cannot proceed without $tool"
      return 0; 
    else 
      echo "OK. Found $tool"
    fi
  done
  
  currentUser=$(whoami)
  if [ "x$currentUser" == "xroot" ]; then
    echo "Check root essentials: ${ROOTESSENTIALS[@]}"
    for tool in "${ROOTESSENTIALS[@]}" 
    do
      local isToolPresent;
      isToolPresent=$(which "$tool")
      if [ "x$isToolPresent" == "x" ]; then
        echo "Cannot proceed without root essential $tool"
        return 0; 
      else 
        echo "OK. Found root essential $tool"
      fi
    done   
  fi
  return 1;
}

function printDiskSpace(){
  df -h
}

function checkOsIsDebian(){
  echo "Checking if Debian"
  local os;
  os=$(uname -v | grep -c 'Debian');  
  if [ "x$os" == "x1" ]; then
    return 1;
  fi
  return 0;
}

function checkSudoPresent(){
  echo "Checking if sudo is present"
  local sudoPresent;
  sudoPresent=$(dpkg -l | grep -c '\ssudo\s');
  if [ "x$sudoPresent" == "x0" ]; then
    return 0;
  fi
  return 1;
}

function checkUserIsSudoer(){
  echo "Checking if user $(whoami) is sudoer"
  local userIsSudoer;
  userIsSudoer=$(getent group sudo | grep -c "$(whoami)")
  if [ "x$userIsSudoer" == "x0" ]; then
    return 0;
  fi
  return 1;
}

function installSudoAsRoot(){
  echo "Installing sudo" 
  apt-get install sudo
  checkSudoPresent
  return $?
}

function createNonRootUser(){
  echo "Creating a non-root user $NONROOTUSER"
  echo "$NONROOTUSER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers	
  useradd $NONROOTUSER -s /bin/bash -m -U -G users,sudo
  chpasswd <<END
$NONROOTUSER:$NONROOTUSER
END
}

function checkPrerequisites(){  
  echo "Checking prerequisites"
  checkEssentials
  local essentialsOk=$?
  if [ $essentialsOk -ne 1 ]; then
    return 1;
  fi
  printDiskSpace 
  checkOsIsDebian
  local osok=$?
  if [ $osok -ne 1 ]; then
    return 2;
  fi
  local currentUser
  currentUser=$(whoami)
  echo "Running as $currentUser" 
  checkSudoPresent
  local sudoPresent=$?
  if [ $sudoPresent -ne 1 ]; then
    if [ "x$currentUser" == "xroot" ]; then
      installSudoAsRoot
      local sudoInstalled=$?
      if [ $sudoInstalled -ne 1 ]; then
        return 3;
      fi
    else
      return 4;
    fi
  fi
  if [ "x$currentUser" == "xroot" ]; then
    createNonRootUser   
  else
    checkUserIsSudoer
    local userIsSudoer=$?
    if [ $userIsSudoer -ne 1 ]; then
      return 5;  
    fi
  fi
}

function updateUpgrade(){
  echo "Update, upgrade and dist-upgrade"
  sudo apt-get -y update
  sudo apt-get -y upgrade
  sudo apt-get -y dist-upgrade
}

function installGit(){
  echo "Installing git"
  sudo apt-get -y install git
  echo "Configuring git" 
  git config --global user.name "SoftSilesia"
  git config --global user.email "softsilesia@mailinator.com"
  echo "Finished configuring git" 
}

function cloneGitRepo(){ 
  installGit
  echo "Cloning git repo"
  if [ -d /tmp/init ]; then
    sudo rm -rf /tmp/init
  fi
  mkdir /tmp/init
  cd /tmp/init || return 0
  git clone "$BITBUCKET_REPO" .  
  return 1
}

function runVersionedInstallation(){
  local branch=$1;
  echo "Running versioned installation file from branch $branch"  
  branchName=$(git branch -r --list | grep -c "$branch")
  if [ "x$branchName" == "x1" ]; then 
    git checkout "$branch"
    chmod -R g-rwx,o-rwx . 
    if [ -d core ]; then 
      cd core
      if [ -f install.sh ]; then
        bash install.sh
      else 
        echo "A script install.sh is not present"
      fi
    else
      echo "Folder core in $branch brach is not present"
    fi
  else
    echo "No $branch branch found"
  fi
}


# do the job
errorsPrerequisites=(
"All prerequisites fulfilled"
"Essentials are missing"
"Not Debian OS"
"Cannot install sudo"
"No sudo installed and user is not root"
"User $(whoami) is not a sudoer"
)

branch=""
if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters. Please provide configuration branch name. For example call: init.sh softsilesia-dev"
    exit;
else
    branch="$1";
fi

checkPrerequisites
result=$?
echo "${errorsPrerequisites[$result]}";
if [ $result -ne 0 ]; then
  exit;
fi

currentUser=$(whoami)
currentScript=$(basename "$0")

if [ "x$currentUser" == "xroot" ]; then
  echo "------------------"
  echo "This script will be executed as non-root user $NONROOTUSER now some preparation steps will be repeated"
  echo "------------------" 
  chown "$NONROOTUSER" "$currentScript" 
  mv "$currentScript" /tmp  
  sudo -u $NONROOTUSER -H -i bash -c "bash /tmp/$currentScript $branch"
elif [ "x$currentUser" == "x$NONROOTUSER" ]; then    	
  updateUpgrade
  cloneGitRepo "$branch"
  result=$?
  if [ $result -eq 1 ]; then
	echo "------------------"
	printDiskSpace
    runVersionedInstallation "$branch"
  else
    echo "Cloning failed"
  fi
fi