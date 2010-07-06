#!/bin/bash
source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/x86

### CLEANING PROCESS ###
clean "${@}"
exit 0
