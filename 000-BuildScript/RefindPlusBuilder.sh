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
BUILD_TOOLS=0
DO_CHECKOUT=1
EDIT_BRANCH="-GOPFix"
DO_SLEEP=1

if [[ $1 == -dbg || $1 == -rel || $1 == -base ]]; then
    BUILD_REL=0
    BUILD_DBG=0
    DO_CHECKOUT=0
    DO_SLEEP=0
fi

while (( $# )); do
    case "${1}" in
        -rel) BUILD_REL=1 ;;
        -dbg) BUILD_DBG=1 ;;
        -base) BUILD_TOOLS=1 ;;
        *) DO_CHECKOUT=1 ; EDIT_BRANCH="$1" ;;
    esac
    shift
done

COLOUR_BASE=""
COLOUR_INFO=""
COLOUR_STATUS=""
COLOUR_ERROR=""
COLOUR_NORMAL=""

if test -t 1; then
    NCOLOURS=$(tput colors)
    if test -n "${NCOLOURS}" && test "${NCOLOURS}" -ge 8; then
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
    echo
    msg_error "${errMessage}"
    echo
    echo
    exit 1
}
trap runErr ERR


# Set things up for build
clear 2> /dev/null || :
msg_info '## RefindPlusBuilder - Setting Up ##'
msg_info '------------------------------------'
BASE_DIR="$(cd "${BASH_SOURCE%/*}/../../" ||  : ; pwd)"
WORK_DIR="${BASE_DIR}/Working"
EDK2_DIR="${BASE_DIR}/edk2"
if [ ! -d "${EDK2_DIR}" ] ; then
    msg_error "ERROR: Could not locate ${EDK2_DIR}"
    echo
    exit 1
fi
XCODE_DIR_REL="${EDK2_DIR}/Build/RefindPlus/RELEASE_XCODE5"
XCODE_DIR_DBG="${EDK2_DIR}/Build/RefindPlus/DEBUG_XCODE5"
BINARY_DIR_REL="${XCODE_DIR_REL}/X64"
BINARY_DIR_DBG="${XCODE_DIR_DBG}/X64"
OUTPUT_DIR="${EDK2_DIR}/000-BOOTx64-Files"
SHASUM='/usr/bin/shasum'
DUP_SHASUM='/usr/local/bin/shasum'
TMP_SHASUM='/usr/local/bin/_shasum'

BASETOOLS_SHA_FILE="${EDK2_DIR}/000-BuildScript/BaseToolsSHA.txt"
if [ ! -f "${BASETOOLS_SHA_FILE}" ] ; then
    BASETOOLS_SHA_OLD='Default'
else
    # shellcheck disable=SC1090
    source "${BASETOOLS_SHA_FILE}" || BASETOOLS_SHA_OLD='Default'
fi
if [ -f "${DUP_SHASUM}" ] ; then
    mv "${DUP_SHASUM}" "${TMP_SHASUM}"
    SHASUM_FIX='true'
else
    SHASUM_FIX='false'
fi

pushd "${EDK2_DIR}/BaseTools" > /dev/null || exit 1
BASETOOLS_SHA_NEW="$(find . -type f -name '*.c' -name '*.h' -name '*.py' -print0 | sort -z | xargs -0 ${SHASUM} | ${SHASUM})"
popd > /dev/null || exit 1

if [ "${SHASUM_FIX}" == 'true' ] ; then
    mv "${TMP_SHASUM}" "${DUP_SHASUM}"
fi
if [ ! -d "${EDK2_DIR}/BaseTools/Source/C/bin" ] || [ "${BASETOOLS_SHA_NEW}" != "${BASETOOLS_SHA_OLD}" ] ; then
    BUILD_TOOLS=1
fi

if (( DO_CHECKOUT )); then
    pushd "${WORK_DIR}" > /dev/null || exit 1
    msg_base "Checkout '${EDIT_BRANCH}' branch..."
    git checkout "${EDIT_BRANCH}" > /dev/null
    msg_status '...OK'; echo
    popd > /dev/null || exit 1
else
    EDIT_BRANCH="current branch"
fi
msg_base 'Update RefindPlusPkg...'

if [[ ! -L "${EDK2_DIR}/RefindPlusPkg" || ! -d "${EDK2_DIR}/RefindPlusPkg" ]]; then
    rm -fr "${EDK2_DIR}/RefindPlusPkg"
    ln -s "${WORK_DIR}" "${EDK2_DIR}/RefindPlusPkg"
fi
msg_status '...OK'; echo

if (( BUILD_TOOLS )) ; then
    pushd "${EDK2_DIR}/BaseTools/Source/C" > /dev/null || exit 1
    msg_base 'Make Clean...'
    make clean
    msg_status '...OK'; echo
    popd > /dev/null || exit 1

    pushd "${EDK2_DIR}" > /dev/null || exit 1
    msg_base 'Make BaseTools...'
    make -C BaseTools/Source/C
    echo '#!/usr/bin/env bash' > "${BASETOOLS_SHA_FILE}"
    echo "BASETOOLS_SHA_OLD='${BASETOOLS_SHA_NEW}'" >> "${BASETOOLS_SHA_FILE}"
    msg_status '...OK'; echo ''
    popd > /dev/null || exit 1
fi


# Basic clean up
clear 2> /dev/null || :
msg_info '## RefindPlusBuilder - Initial Clean Up ##'
msg_info '------------------------------------------'
mkdir -p "${EDK2_DIR}/Build"
if [ -d "${OUTPUT_DIR}" ] ; then
    rm -fr "${OUTPUT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"
echo
echo

DoBuild () {
    local BUILD_TYPE="$1"
    local BUILD_OPTION="$2"
    local XCODE_DIR="$3"
    
    clear 2> /dev/null || :
    msg_info "## RefindPlusBuilder - Building ${BUILD_TYPE} Version ##"
    msg_info '----------------------------------------------'
    pushd "${EDK2_DIR}" > /dev/null || exit 1
    if [ -d "${XCODE_DIR}" ] ; then
        rm -fr "${XCODE_DIR}"
    fi
    if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
        rm -fr "${EDK2_DIR}/.Build-TMP"
    fi

    source edksetup.sh BaseTools
    build -b "${BUILD_OPTION}"

    if [ -d "${EDK2_DIR}/.Build-TMP" ] ; then
        rm -fr "${EDK2_DIR}/.Build-TMP"
    fi
    popd > /dev/null || exit 1
    echo
    msg_info "Completed ${BUILD_TYPE} Build on ${EDIT_BRANCH} of RefindPlus"
    echo
}

# Build release version
if (( BUILD_REL )); then
    # Build release version
    DoBuild REL RELEASE "${XCODE_DIR_REL}"

    if (( BUILD_DBG )); then
        msg_info 'Preparing DBG Build...'
        echo
        if (( DO_SLEEP )); then
            sleep 4
        fi
    fi
fi


# Build debug version
if (( BUILD_DBG )); then
    # Build debug version
    DoBuild DBG DEBUG "${XCODE_DIR_DBG}"
fi


# Copy debug and release versions even if we only built one of them or neither
if [ -f "${BINARY_DIR_DBG}/RefindPlus.efi" ] ; then
    cp -p "${BINARY_DIR_DBG}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-DBG.efi"
fi
if [ -f "${BINARY_DIR_REL}/RefindPlus.efi" ] ; then
    cp -p "${BINARY_DIR_REL}/RefindPlus.efi" "${OUTPUT_DIR}/BOOTx64-REL.efi"
fi


# Tidy up
echo
msg_info 'Output EFI Files...'
msg_status "RefindPlus EFI Files (BOOTx64)      : '${OUTPUT_DIR}'"
msg_status "RefindPlus EFI Files (Others - DBG) : '${XCODE_DIR_DBG}/X64'"
msg_status "RefindPlus EFI Files (Others - REL) : '${XCODE_DIR_REL}/X64'"
echo
echo
