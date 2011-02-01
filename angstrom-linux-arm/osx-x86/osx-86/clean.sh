#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac and Lawrence Chan
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/arm_angstrom

### CLEANING PROCESS ###
clean "${@}"
exit 0
