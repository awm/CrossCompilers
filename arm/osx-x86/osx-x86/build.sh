#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# set binutils, gcc, newlib versions
BINUTILS_VERSION=2.21
GCC_VERSION=4.5.3
GMP_VERSION=5.0.2
MPFR_VERSION=3.0.1
MPC_VERSION=0.9
NEWLIB_VERSION=1.19.0
GDB_VERSION=7.2

# set CFLAGS
BINUTILS_CFLAGS=""
GCC_CFLAGS=""
NEWLIB_CFLAGS=""
GDB_CFLAGS=""

# target system
TARGET_SYSTEM=arm-elf-eabi

# languages
LANGUAGES="c"

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/arm

# set package names
BINUTILS_PACKAGE=binutils-${BINUTILS_VERSION}
GCC_PACKAGE=gcc-${GCC_VERSION}
GMP_PACKAGE=gmp-${GMP_VERSION}
MPFR_PACKAGE=mpfr-${MPFR_VERSION}
MPC_PACKAGE=mpc-${MPC_VERSION}
NEWLIB_PACKAGE=newlib-${NEWLIB_VERSION}
GDB_PACKAGE=gdb-${GDB_VERSION}

# set download file names
BINUTILS_FILE=${BINUTILS_PACKAGE}.tar.bz2
GCC_FILE=gcc-${GCC_VERSION}.tar.bz2
GMP_FILE=${GMP_PACKAGE}.tar.bz2
MPFR_FILE=${MPFR_PACKAGE}.tar.bz2
MPC_FILE=${MPC_PACKAGE}.tar.gz
NEWLIB_FILE=${NEWLIB_PACKAGE}.tar.gz
GDB_FILE=${GDB_PACKAGE}.tar.bz2

# set download URLs
BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/${BINUTILS_FILE}"
GCC_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GCC_FILE}"
GMP_URL="ftp://ftp.gnu.org/gnu/gmp/${GMP_FILE}"
MPFR_URL="http://www.mpfr.org/mpfr-current/${MPFR_FILE}"
MPC_URL="http://www.multiprecision.org/mpc/download/${MPC_FILE}"
NEWLIB_URL="ftp://sources.redhat.com/pub/newlib/${NEWLIB_FILE}"
GDB_URL="http://ftp.gnu.org/gnu/gdb/${GDB_FILE}"

### BUILD PROCESS ###
status "BUILDING OS X TO ARM CROSS COMPILER...."
START_TIME=`date +%s`
check_prerequesites

# create some needed directories
status "Creating directories...."
# first check if they exist, then create them if they don't
cond_mkdir "${CROSS_DIR}"
cond_mkdir "${DL_DIR}"
cond_mkdir "${SRC_DIR}"
cond_mkdir "${TEST_DIR}"
cond_mkdir "${BUILD_DIR}/${BINUTILS_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${NEWLIB_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GDB_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}-bootstrap"
cond_mkdir "${CROSS_DIR}/usr"

# download the needed packages
status "Downloading packages (if needed)...."
download "${BINUTILS_URL}"
download_patches "${BINUTILS_PACKAGE}" binutils-patches.txt
download "${GCC_URL}"
download "${GMP_URL}"
download "${MPFR_URL}"
download "${MPC_URL}"
download "${NEWLIB_URL}"
download "${GDB_URL}"

# only extract binutils if needed
cond_extract "" "${BINUTILS_PACKAGE}" "${BINUTILS_FILE}"

apply_patches $BINUTILS_PACKAGE

# build binutils
status "Building ${BINUTILS_PACKAGE}...."
cd ${BUILD_DIR}/${BINUTILS_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${BINUTILS_PACKAGE}/configure	\
						--prefix=${CROSS_DIR}		\
						--with-sysroot=${CROSS_DIR} \
						--target=${TARGET_SYSTEM}	\
						--with-gcc					\
						--with-gnu-as				\
						--with-gnu-ld				\
						--disable-nls				\
						--disable-shared			\
						--enable-interwork			\
						--with-float=soft			\
						--disable-werror            ||
	abort "Failed to configure ${BINUTILS_PACKAGE}"
[ -f ld/ld-new ] || make CFLAGS="${BINUTILS_CFLAGS}" || abort "Failed to build ${BINUTILS_PACKAGE}"
[ -x ${CROSS_DIR}/bin/${TARGET_SYSTEM}-ld ] || make install || abort "Failed to install ${BINUTILS_PACKAGE}"
cd - > /dev/null

# only extract gmp if needed
cond_extract "" "${GMP_PACKAGE}" "${GMP_FILE}"

# only extract mpfr if needed
cond_extract "" "${MPFR_PACKAGE}" "${MPFR_FILE}"

# only extract mpc if needed
cond_extract "" "${MPC_PACKAGE}" "${MPC_FILE}"

# only extract newlib if not done
cond_extract "" "${NEWLIB_PACKAGE}" "${NEWLIB_FILE}"

# only copy newlib includes if not done
if [ ! -f "${CROSS_DIR}/usr/include/newlib.h" ]; then
	# copy newlib includes
	status "Copying ${NEWLIB_PACKAGE} include files...."
	cp -R ${SRC_DIR}/${NEWLIB_PACKAGE}/newlib/libc/include ${CROSS_DIR}/usr/ || abort "Failed to copy ${NEWLIB_PACKAGE} includes"
fi

# only extract gcc if not done
cond_extract "" "${GCC_PACKAGE}" "${GCC_FILE}"

# create library links
status "Creating numeric library links...."
cd ${SRC_DIR}/${GCC_PACKAGE}
ln -sf ../${GMP_PACKAGE} gmp || abort "Failed to create GMP link"
ln -sf ../${MPFR_PACKAGE} mpfr || abort "Failed to create MPFR link"
ln -sf ../${MPC_PACKAGE} mpc || abort "Failed to create MPC link"
cd - > /dev/null

# needed for MPFR to find GMP internal headers
export CPPFLAGS="-I`pwd`/${SRC_DIR}/${GMP_PACKAGE}"

apply_patches $GCC_PACKAGE

# build gcc
status "Building '${GCC_PACKAGE}'...."
cd ${BUILD_DIR}/${GCC_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${GCC_PACKAGE}/configure			\
						--prefix=${CROSS_DIR}			\
						--target=${TARGET_SYSTEM}		\
						--with-gcc						\
						--with-gnu-as					\
						--with-gnu-ld					\
						--disable-nls					\
						--enable-languages=${LANGUAGES}	\
						--enable-interwork				\
						--with-float=soft				\
						--enable-multilib				\
						--disable-threads				\
						--without-headers				\
						--disable-libssp				||
	abort "Failed to configure '${GCC_PACKAGE}'"
[ -f "gcc/gcc" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
make install || abort "Failed to install '${GCC_PACKAGE}'"
cd - > /dev/null

# test new compiler
status "Testing compiler...."
${TARGET_SYSTEM}-gcc "${TEST_SRC_DIR}/test_nolibc.c" -nostartfiles -nostdlib -mthumb -mcpu=cortex-m0 -o "${TEST_DIR}/test_cm0-c" || abort "C test compilation failed"
${TARGET_SYSTEM}-gcc "${TEST_SRC_DIR}/test_nolibc.c" -nostartfiles -nostdlib -mcpu=arm926ej-s -o "${TEST_DIR}/test_arm9-c" || abort "C test compilation failed"
${TARGET_SYSTEM}-gcc "${TEST_SRC_DIR}/test_nolibc.c" -nostartfiles -nostdlib -mcpu=arm7tdmi -o "${TEST_DIR}/test_arm7-c" || abort "C test compilation failed"

# only extract gdb if not done
cond_extract "" "${GDB_PACKAGE}" "${GDB_FILE}"

# build gdb
status "Building '${GDB_PACKAGE}'...."
cd ${BUILD_DIR}/${GDB_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${GDB_PACKAGE}/configure		\
						--prefix=${CROSS_DIR}		\
						--with-sysroot=${CROSS_DIR} \
						--target=${TARGET_SYSTEM}	\
						--disable-nls				\
						--enable-interwork			\
						--enable-multilib			\
						--with-float=soft			||
	abort "Failed to configure '${GDB_PACKAGE}'"
[ -f "gdb/gdb" ] || make CFLAGS="${GDB_CFLAGS}" || abort "Failed to build '${GDB_PACKAGE}'"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-gdb" ] || make install || abort "Failed to install '${GDB_PACKAGE}'"
cd - > /dev/null

# all done
END_TIME=`date +%s`
ELAPSED_TIME=$((${END_TIME} - ${START_TIME}))
ELAPSED_TIME_MIN=$(((${ELAPSED_TIME} + 30) / 60))
success "OS X TO ARM CROSS COMPILER BUILT IN '${CROSS_DIR}'"
success "Total Size: `du -hsc ${CROSS_DIR} | grep 'total' | awk '{ print $1; }'`"
success "Elapsed Time: ${ELAPSED_TIME} seconds (${ELAPSED_TIME_MIN} minutes)"
exit 0
