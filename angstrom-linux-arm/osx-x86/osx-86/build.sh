#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac and Lawrence Chan
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# set binutils, gcc, newlib versions
BINUTILS_VERSION=2.21
GCC_VERSION=4.5.2
GMP_VERSION=5.0.1
MPFR_VERSION=3.0.0
MPC_VERSION=0.8.2

# set CFLAGS
BINUTILS_CFLAGS=""
GCC_CFLAGS=""

# target system
TARGET_SYSTEM=arm-angstrom-linux-gnueabi

# languages
LANGUAGES="c,c++,objc"

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/arm_angstrom

# set package names
BINUTILS_PACKAGE=binutils-${BINUTILS_VERSION}
GCC_PACKAGE=gcc-${GCC_VERSION}
GMP_PACKAGE=gmp-${GMP_VERSION}
MPFR_PACKAGE=mpfr-${MPFR_VERSION}
MPC_PACKAGE=mpc-${MPC_VERSION}
ANGSTROM_TOOLCHAIN_PACKAGE=angstrom-at91sam9xe

# set download file names
BINUTILS_FILE=${BINUTILS_PACKAGE}.tar.bz2
GCC_FILE=gcc-${GCC_VERSION}.tar.bz2
GMP_FILE=${GMP_PACKAGE}.tar.bz2
MPFR_FILE=${MPFR_PACKAGE}.tar.bz2
MPC_FILE=${MPC_PACKAGE}.tar.gz
ANGSTROM_TOOLCHAIN_FILE=${ANGSTROM_TOOLCHAIN_PACKAGE}.tar.gz

# set download URLs
BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/${BINUTILS_FILE}"
GCC_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GCC_FILE}"
GMP_URL="ftp://gcc.gnu.org/pub/gcc/infrastructure/${GMP_FILE}"
MPFR_URL="ftp://gcc.gnu.org/pub/gcc/infrastructure/${MPFR_FILE}"
MPC_URL="ftp://gcc.gnu.org/pub/gcc/infrastructure/${MPC_FILE}"

### BUILD PROCESS ###
status "BUILDING OS X TO ARM ANGSTRÖM LINUX CROSS COMPILER...."
check_prerequesites

# create some needed directories
status "Creating directories...."
# first check if they exist, then create them if they don't
cond_mkdir "${CROSS_DIR}"
cond_mkdir "${SRC_DIR}"
cond_mkdir "${TEST_DIR}"
cond_mkdir "${BUILD_DIR}/${BINUTILS_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}"
cond_mkdir "${CROSS_DIR}/usr"

# download the needed packages
status "Downloading packages (if needed)...."
download "${BINUTILS_URL}"
download "${GCC_URL}"
download "${GMP_URL}"
download "${MPFR_URL}"
download "${MPC_URL}"

# only extract binutils if needed
cond_extract "" "${BINUTILS_PACKAGE}" "${BINUTILS_FILE}"

# build binutils
status "Building ${BINUTILS_PACKAGE}...."
cd ${BUILD_DIR}/${BINUTILS_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${BINUTILS_PACKAGE}/configure	\
						--prefix=${CROSS_DIR}		\
						--with-sysroot=${CROSS_DIR} \
						--target=${TARGET_SYSTEM}	\
						--disable-nls				\
						--enable-shared			    \
						--enable-interwork			\
						--disable-werror            ||
	abort "Failed to configure ${BINUTILS_PACKAGE}"
[ -f "ld/ld-new" ] || make CFLAGS="${BINUTILS_CFLAGS}" || abort "Failed to build ${BINUTILS_PACKAGE}"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-ld" ] || make install || abort "Failed to install ${BINUTILS_PACKAGE}"
cd - > /dev/null

# only extract angstrom toolchain if not done
cond_extract "" "${ANGSTROM_TOOLCHAIN_PACKAGE}" "${ANGSTROM_TOOLCHAIN_FILE}"

# only copy angstrom files if not done
if [ ! -f "${CROSS_DIR}/lib/libc-2.12.1.so" ]; then
	# copy includes
	status "Copying ${ANGSTROM_TOOLCHAIN_PACKAGE} files...."
	cond_mkdir "${CROSS_DIR}/usr/include"
	cp -Rp ${SRC_DIR}/${ANGSTROM_TOOLCHAIN_PACKAGE}/usr/include/* ${CROSS_DIR}/usr/include || abort "Failed to copy ${ANGSTROM_TOOLCHAIN_PACKAGE} includes"
	cond_mkdir "${CROSS_DIR}/lib"
	cp -Rp ${SRC_DIR}/${ANGSTROM_TOOLCHAIN_PACKAGE}/lib/* ${CROSS_DIR}/lib || abort "Failed to copy ${ANGSTROM_TOOLCHAIN_PACKAGE} libraries"
	cond_mkdir "${CROSS_DIR}/usr/lib"
	cp -Rp ${SRC_DIR}/${ANGSTROM_TOOLCHAIN_PACKAGE}/usr/lib/* ${CROSS_DIR}/usr/lib || abort "Failed to copy ${ANGSTROM_TOOLCHAIN_PACKAGE} libraries"
fi

# only extract gmp if needed
cond_extract "" "${GMP_PACKAGE}" "${GMP_FILE}"

# only extract mpfr if needed
cond_extract "" "${MPFR_PACKAGE}" "${MPFR_FILE}"

# only extract mpc if needed
cond_extract "" "${MPC_PACKAGE}" "${MPC_FILE}"

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

# build gcc/g++
status "Building '${GCC_PACKAGE}'...."
cd ${BUILD_DIR}/${GCC_PACKAGE}
[ -f Makefile ] ||
  ../../${SRC_DIR}/${GCC_PACKAGE}/configure         	\
                      --prefix=${CROSS_DIR}         	\
                      --with-sysroot=${CROSS_DIR}   	\
                      --target=${TARGET_SYSTEM}     	\
                      --disable-nls                 	\
                      --enable-languages=${LANGUAGES}	\
                      --enable-interwork            	\
                      --with-float=soft             	\
                      --enable-multilib             	\
                      --enable-threads=posix        	\
                      --enable-shared               	\
                      --enable-c99                  	\
                      --enable-long-long            	\
                      --enable-__cxa_atexit         	||
  abort "Failed to configure '${GCC_PACKAGE}'"
[ -f "gcc/g++" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-g++" ] || make install || abort "Failed to install '${GCC_PACKAGE}'"

# test new compiler
status "Testing compiler...."
export PATH="${CROSS_DIR}/bin:${PATH}"
${TARGET_SYSTEM}-gcc "${TEST_SRC_DIR}/test.c" -o "${TEST_DIR}/test-c" || abort "C test compilation failed"
${TARGET_SYSTEM}-g++ "${TEST_SRC_DIR}/test.cpp" -o "${TEST_DIR}/test-cpp" || abort "C++ test compilation failed"
${TARGET_SYSTEM}-gcc "${TEST_SRC_DIR}/test.m" -o "${TEST_DIR}/test-objc" || abort "Objective-C test compilation failed"

# all done
success "OS X TO ARM ANGSTRÖM LINUX CROSS COMPILER BUILT IN '${CROSS_DIR}'"
success "Total Size: "`du -hsc ${CROSS_DIR} | grep 'total' | awk '{ print $1; }'`
exit 0
