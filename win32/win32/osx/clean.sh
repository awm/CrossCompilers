#!/bin/bash
source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR="`pwd`/install"

### CLEANING PROCESS ###
clean "${@}"
exit 0
