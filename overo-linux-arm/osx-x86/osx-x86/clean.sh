#!/bin/bash
source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/overo-linux-arm

### CLEANING PROCESS ###
clean "${@}"
exit 0
