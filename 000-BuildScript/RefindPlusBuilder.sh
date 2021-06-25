#!/usr/bin/env bash

###
 # RefindPlusBuilder.sh
 # A script to build RefindPlus
 #
 # Copyright (c) 2020-2021 Dayo Akanji
 # MIT License
###

# Parse parameters, setup colors if terminal
BUILD_REL=1
BUILD_DBG=1
BASETOOLS=0

if [[ $1 == -dbg || $1 == -rel || $1 == -base ]]; then
	BUILD_REL=0
	BUILD_DBG=0
fi

if [[ $1 == -rel ]]; then
    BUILD_REL=1
    shift
fi

if [[ $1 == -dbg ]]; then
    BUILD_DBG=1
    shift
fi

if [[ $1 == -base ]]; then
    BASETOOLS=1
    shift
fi

COLOUR_BASE=""
COLOUR_INFO=""
COLOUR_STATUS=""
COLOUR_ERROR=""
COLOUR_NORMAL=""

if test -t 1; then
    NCOLOURS=$(tput colors)
    if test -n "${NCOLOURS}" && test ${NCOLOURS} -ge 8; then
        COLOUR_BASE="\033[0;36m"
        COLOUR_INFO="\033[0;33m"
        COLOUR_STATUS="\033[0;32m"
        COLOUR_ERROR="\033[0;31m"
        COLOUR_NORMAL="\033[0m"
    fi
fi

# Provide custom colours
msg_base() {
    echo -e "${COLOUR_BASE}${1}${COLOUR_NORMAL}"
}
msg_info() {
    echo -e "${COLOUR_INFO}${1}${COLOUR_NORMAL}"
}
msg_status() {
    echo -e "${COLOUR_STATUS}${1}${COLOUR_NORMAL}"
}
msg_error() {
    echo -e "${COLOUR_ERROR}${1}${COLOUR_NORMAL}"
}

## ERROR HANDLER ##
runErr() { # $1: message
    # Declare Local Variables
    local errMessage

    errMessage="${1:-Runtime Error ... Exiting}"
    echo ''
    msg_error "${errMessage}"
    echo ''
    echo ''
    exit 1
}
trap runErr ERR


# Set things up for build
msg_info '## RefindPlusBuilder - Setting Up ##'
msg_info '------------------------------------'
BASE_DIR="$(cd "${BASH_SOURCE%/*}/../../"; pwd)"
WORK_DIR="${BASE_DIR}/Working"
EDK2_DIR="${BASE_DIR}/edk2"
if [ ! -d "${EDK2_DIR}" ] ; then
    msg_error "ERROR: Could not locate ${EDK2_DIR}"
    echo ''
    exit 1
fi
XCODE_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_XCODE5"
XCODE_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_XCODE5"
BINARY_DIR_REL="${XCODE_DIR_REL}/X64"
BINARY_DIR_DBG="${XCODE_DIR_DBG}/X64"
OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"
GLOBAL_FILE="${EDK2_DIR}/RefindPlusPkg/BootMaster/globalExtra.h"
GLOBAL_FILE_TMP_REL="${EDK2_DIR}/RefindPlusPkg/BootMaster/globalExtra-REL.txt"
GLOBAL_FILE_TMP_DBG="${EDK2_DIR}/RefindPlusPkg/BootMaster/globalExtra-DBG.txt"
BUILD_DSC="${EDK2_DIR}/RefindPlusPkg/RefindPlusPkg.dsc"
BUILD_DSC_REL="${EDK2_DIR}/RefindPlusPkg/RefindPlusPkg-REL.dsc"
BUILD_DSC_DBG="${EDK2_DIR}/RefindPlusPkg/RefindPlusPkg-DBG.dsc"
if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] ; then
    BASETOOLS=1
fi

msg_base 'Update RefindPlusPkg...'
if [[ ! -L "${EDK2_DIR}/RefindPlusPkg" || ! -d "${EDK2_DIR}/RefindPlusPkg" ]]; then
	rm -fr "${EDK2_DIR}/RefindPlusPkg"
    ln -s "${WORK_DIR}" "${EDK2_DIR}/RefindPlusPkg"
fi
msg_status '...OK'; echo ''

if (( BASETOOLS )) ; then
    pushd "${EDK2_DIR}/BaseTools/Source/C" > /dev/null || exit 1
    msg_base 'Make Clean...'
    make clean
    msg_status '...OK'; echo ''
    popd > /dev/null || exit 1

    pushd "${EDK2_DIR}" > /dev/null || exit 1
    msg_base 'Make BaseTools...'
    make -C BaseTools/Source/C
    msg_status '...OK'; echo ''
    popd > /dev/null || exit 1
fi


# Basic clean up
msg_info '## RefindPlusBuilder - Initial Clean Up ##'
msg_info '------------------------------------------'

if [ -d "${EDK2_DIR}/Build" ] ; then
    rm -fr "${EDK2_DIR}/Build"
fi
mkdir -p "${EDK2_DIR}/Build"
if [ -d "${OUTPUT_DIR}" ] ; then
    rm -fr "${OUTPUT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"


DoBuild () {
    local BuildType="$1"
    local BuildOption="$2"
    local GLOBAL_FILE_TMP="$3"
    local BUILD_DSC_TMP="$4"
    local BINARY_DIR="$5"
    
    #clear
    msg_info "## RefindPlusBuilder - Building $BuildType Version ##"
    msg_info '----------------------------------------------'

    pushd "${EDK2_DIR}" > /dev/null || exit 1
    if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
        rm -fr "${EDK2_DIR}/.Build-TMP"
    fi
    if [ -f "${GLOBAL_FILE}" ] ; then
        rm -fr "${GLOBAL_FILE}"
    fi
    cp "${GLOBAL_FILE_TMP}" "${GLOBAL_FILE}"

    if [ -f "${BUILD_DSC}" ] ; then
        rm -fr "${BUILD_DSC}"
    fi
    cp "${BUILD_DSC_TMP}" "${BUILD_DSC}"

    source edksetup.sh BaseTools
    build -b $BuildOption

    if [ -d "${EDK2_DIR}/Build" ] ; then
        cp "${BINARY_DIR}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-${BuildType}.efi"
    fi
    if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
        rm -fr "${EDK2_DIR}/.Build-TMP"
    fi
    popd > /dev/null || exit 1
    echo ''
    msg_info "Completed ${BuildType} Build on current branch of RefindPlus"
    echo ''
}


if ((BUILD_REL)); then
    # Build release version
    DoBuild REL RELEASE "${GLOBAL_FILE_TMP_REL}" "${BUILD_DSC_REL}" "${BINARY_DIR_REL}"
fi

if ((BUILD_DBG)); then
    # Build debug version
    DoBuild DBG DEBUG "${GLOBAL_FILE_TMP_DBG}" "${BUILD_DSC_DBG}" "${BINARY_DIR_DBG}"
fi


# Tidy up
if [ -f "${GLOBAL_FILE}" ] ; then
    rm -fr "${GLOBAL_FILE}"
fi
cp "${GLOBAL_FILE_TMP_REL}" "${GLOBAL_FILE}"
if [ -f "${BUILD_DSC}" ] ; then
    rm -fr "${BUILD_DSC}"
fi
echo ''
msg_info 'Output EFI Files...'
msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
msg_status "RefindPlus EFI Files (Others - DBG) : '${XCODE_DIR_DBG}/X64'"
msg_status "RefindPlus EFI Files (Others - REL) : '${XCODE_DIR_REL}/X64'"
echo ''
echo ''
