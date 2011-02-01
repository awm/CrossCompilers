#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR=`pwd`/angstrom-linux-arm

### CLEANING PROCESS ###
clean "${@}"
exit 0
