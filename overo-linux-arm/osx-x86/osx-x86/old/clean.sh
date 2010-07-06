#!/bin/bash
source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/arm-angstrom

### CLEANING PROCESS ###
clean "${@}"

if [ "x${1}" = "x--source" ]; then
    rm -R ${DL_DIR}/*-patches
fi
exit 0
