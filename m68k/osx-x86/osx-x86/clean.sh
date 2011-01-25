#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/m68k

### CLEANING PROCESS ###
clean "${@}"
exit 0
