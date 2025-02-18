#!/bin/bash
# Copyright (c) 2016-19 Jetsonhacks 
# MIT License
# Build kernel to include tegra usb firmware

JETSON_MODEL="NVIDIA Jetson Nano Developer Kit"
L4T_TARGET="32.2"
SOURCE_TARGET="/usr/src"
KERNEL_RELEASE="4.9"
BUILD_REPOSITORY="$HOME/buildKernelAndModules"
INSTALL_DIR=$PWD

# < is more efficient than cat command
# NULL byte at end of board description gets bash upset; strip it out
JETSON_BOARD=$(tr -d '\0' </proc/device-tree/model)

# Starting with L4T 32.2, the recommended way to find the L4T Release Number
# is to use dpkg
function check_L4T_version()
{   
        if [ -f /etc/nv_tegra_release ]; then
		JETSON_L4T_STRING=$(head -n 1 /etc/nv_tegra_release)
		JETSON_L4T_RELEASE=$(echo $JETSON_L4T_STRING | cut -f 2 -d ' ' | grep -Po '(?<=R)[^;]+')
		JETSON_L4T_REVISION=$(echo $JETSON_L4T_STRING | cut -f 2 -d ',' | grep -Po '(?<=REVISION: )[^;]+')

	else
		echo "$LOG Reading L4T version from \"dpkg-query --show nvidia-l4t-core\""

		JETSON_L4T_STRING=$(dpkg-query --showformat='${Version}' --show nvidia-l4t-core)
		local JETSON_L4T_ARRAY=(${JETSON_L4T_STRING//./ })	

		#echo ${JETSON_L4T_ARRAY[@]}
		#echo ${#JETSON_L4T_ARRAY[@]}

		JETSON_L4T_RELEASE=${JETSON_L4T_ARRAY[0]}
		JETSON_L4T_REVISION=${JETSON_L4T_ARRAY[1]}
	fi

	JETSON_L4T_VERSION="$JETSON_L4T_RELEASE.$JETSON_L4T_REVISION"
	echo "$LOG Jetson BSP Version:  L4T R$JETSON_L4T_VERSION"

}

echo "Getting L4T Version"
check_L4T_version
JETSON_L4T="$JETSON_L4T_VERSION"
echo "Jetson_L4T="$JETSON_L4T


LAST="${SOURCE_TARGET: -1}"
if [ $LAST != '/' ] ; then
   SOURCE_TARGET="$SOURCE_TARGET""/"
fi

# Error out if something goes wrong
set -e

# Check to make sure we're installing the correct kernel sources
# Determine the correct kernel version
# The KERNEL_BUILD_VERSION is the release tag for the JetsonHacks buildKernel repository
KERNEL_BUILD_VERSION=master
if [ "$JETSON_BOARD" == "$JETSON_MODEL" ] ; then 
  if [ $JETSON_L4T == "$L4T_TARGET" ] ; then
     KERNEL_BUILD_VERSION=$L4T_TARGET
  else
   echo ""
   tput setaf 1
   echo "==== L4T Kernel Version Mismatch! ============="
   tput sgr0
   echo ""
   echo "This repository is for modifying the kernel for a L4T "$L4T_TARGET "system." 
   echo "You are attempting to modify a L4T "$JETSON_MODEL "system with L4T "$JETSON_L4T
   echo "The L4T releases must match!"
   echo ""
   echo "There may be versions in the tag/release sections that meet your needs"
   echo ""
   exit 1
  fi
else 
   tput setaf 1
   echo "==== Jetson Board Mismatch! ============="
   tput sgr0
    echo "Currently this script works for the $JETSON_MODEL."
   echo "This processor appears to be a $JETSON_BOARD, which does not have a corresponding script"
   echo ""
   echo "Exiting"
   exit 1
fi

# Check to see if buildKernelAndModules is installed
# Expect it in the home directory
if [ -d "$BUILD_REPOSITORY" ] ; then
   echo "buildModules and Kernel previously installed"
else
   echo "Installing buildModulesAndKernel"
   git clone https://github.com/jetsonhacksnano/buildKernelAndModules "$BUILD_REPOSITORY"
fi

cd $BUILD_REPOSITORY
git checkout vL4T32.2
cd $INSTALL_DIR

# Check to see if source tree is already installed
PROPOSED_SRC_PATH="$SOURCE_TARGET""kernel/kernel-"$KERNEL_RELEASE
echo "Proposed source path: ""$PROPOSED_SRC_PATH"
if [ -d "$PROPOSED_SRC_PATH" ]; then
  echo "==== Kernel source appears to already be installed =============== "
else 
  # Get the kernel sources
  cd $BUILD_REPOSITORY
  ./getKernelSources.sh
  cd $INSTALL_DIR
fi

# Add the USB driver to the kernel
export SOURCE_TARGET
export KERNEL_RELEASE
sudo -E ./scripts/configureKernel.sh

# Make the kernel
echo "Making kernel"
cd $BUILD_REPOSITORY
./makeKernel.sh
if [ $? -eq 0 ]; then
   # Put a copy of the current Image here
   cp /boot/Image $INSTALL_DIR/Image.orig
   ./copyImage.sh
   echo "New Image created and placed in /boot"
fi


