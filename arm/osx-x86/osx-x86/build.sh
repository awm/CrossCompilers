#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# set whether of not to enable C++ support
ENABLE_CXX=0

# set binutils, gcc, newlib versions
BINUTILS_VERSION=2.20.1
GCC_VERSION=4.5.1
GMP_VERSION=5.0.1
MPFR_VERSION=3.0.0
MPC_VERSION=0.8.2
NEWLIB_VERSION=1.18.0
GDB_VERSION=7.2

# set CFLAGS
BINUTILS_CFLAGS=""
GCC_CFLAGS=""
NEWLIB_CFLAGS=""
GDB_CFLAGS=""

# target system
TARGET_SYSTEM=arm-elf-eabi

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
# T_ARM_ELF_FILE=t-arm-elf

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
check_prerequesites

# create some needed directories
status "Creating directories...."
# first check if they exist, then create them if they don't
cond_mkdir "${CROSS_DIR}"
cond_mkdir "${DL_DIR}"
cond_mkdir "${SRC_DIR}"
cond_mkdir "${BUILD_DIR}/${BINUTILS_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${NEWLIB_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GDB_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}-bootstrap"
cond_mkdir "${CROSS_DIR}/usr"

# download the needed packages
status "Downloading packages (if needed)...."
download "${BINUTILS_URL}"
download "${GCC_URL}"
download "${GMP_URL}"
download "${MPFR_URL}"
download "${MPC_URL}"
download "${NEWLIB_URL}"
download "${GDB_URL}"

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

# enable additional gcc arm options
# status "Enabling additional GCC ARM library options...."
# enable multilib options
# cp ${T_ARM_ELF_FILE} ${SRC_DIR}/${GCC_PACKAGE}/gcc/config/arm/${T_ARM_ELF_FILE} || abort "Failed to enable options"

# create library links
status "Creating numeric library links...."
cd ${SRC_DIR}/${GCC_PACKAGE}
ln -sf ../${GMP_PACKAGE} gmp || abort "Failed to create GMP link"
ln -sf ../${MPFR_PACKAGE} mpfr || abort "Failed to create MPFR link"
ln -sf ../${MPC_PACKAGE} mpc || abort "Failed to create MPC link"
cd - > /dev/null

# needed for MPFR to find GMP internal headers
export CPPFLAGS="-I`pwd`/${SRC_DIR}/${GMP_PACKAGE}"

status "Building bootstrapping compiler...."
cd ${BUILD_DIR}/${GCC_PACKAGE}-bootstrap
[ -f Makefile ] ||
	../../${SRC_DIR}/${GCC_PACKAGE}/configure	    \
						--prefix=${CROSS_DIR}	    \
						--with-sysroot=${CROSS_DIR} \
						--target=${TARGET_SYSTEM}   \
						--with-gcc				    \
						--with-gnu-as			    \
						--with-gnu-ld			    \
						--disable-nls			    \
						--enable-languages=c	    \
						--enable-interwork		    \
						--disable-shared		    \
						--with-float=soft		    \
						--with-newlib			    \
						--enable-multilib		    \
						--disable-threads		    ||
	abort "Failed to configure bootstrapping compiler"
[ -f "gcc/gcc" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build bootstrapping compiler"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-gcc" ] || make install || abort "Failed to install bootstrapping compiler"
export PATH="${PATH}:${CROSS_DIR}/bin"
cd - > /dev/null

status "Building ${NEWLIB_PACKAGE}...."
cd ${BUILD_DIR}/${NEWLIB_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${NEWLIB_PACKAGE}/configure	\
						--prefix=${CROSS_DIR}		\
						--target=${TARGET_SYSTEM}	\
						--enable-interwork			\
						--disable-shared			\
						--with-float=soft			\
						--enable-multilib			||
	abort "Failed to configure ${NEWLIB_PACKAGE}"
[ -f "${TARGET_SYSTEM}/newlib/libc.a" ] || make CFLAGS="${NEWLIB_CFLAGS}" || abort "Failed to build ${NEWLIB_PACKAGE}"
[ -f "${CROSS_DIR}/${TARGET_SYSTEM}/lib/libc.a" ] || make install || abort "Failed to install ${NEWLIB_PACKAGE}"
cd - > /dev/null

if [ ${ENABLE_CXX} -ne 0 ]; then
	# build gcc/g++
	status "Building '${GCC_PACKAGE}'...."
	cd ${BUILD_DIR}/${GCC_PACKAGE}
	[ -f Makefile ] ||
		../../${SRC_DIR}/${GCC_PACKAGE}/configure		\
							--prefix=${CROSS_DIR}		\
							--with-sysroot=${CROSS_DIR} \
							--target=${TARGET_SYSTEM}	\
							--with-gcc					\
							--with-gnu-as				\
							--with-gnu-ld				\
							--disable-nls				\
							--enable-languages=c,c++	\
							--enable-interwork			\
							--with-float=soft			\
							--with-newlib				\
							--enable-multilib			\
							--disable-threads			||
		abort "Failed to configure '${GCC_PACKAGE}'"
	[ -f "gcc/g++" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
	[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-g++" ] || make install || abort "Failed to install '${GCC_PACKAGE}'"
else
	# build gcc
	status "Building '${GCC_PACKAGE}'...."
	cd ${BUILD_DIR}/${GCC_PACKAGE}
	[ -f Makefile ] ||
		../../${SRC_DIR}/${GCC_PACKAGE}/configure		\
							--prefix=${CROSS_DIR}		\
							--with-sysroot=${CROSS_DIR} \
							--target=${TARGET_SYSTEM}	\
							--with-gcc					\
							--with-gnu-as				\
							--with-gnu-ld				\
							--disable-nls				\
							--enable-languages=c		\
							--enable-interwork			\
							--with-float=soft			\
							--with-newlib				\
							--enable-multilib			\
							--disable-threads			||
		abort "Failed to configure '${GCC_PACKAGE}'"
	[ -f "gcc/gcc" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
	make install || abort "Failed to install '${GCC_PACKAGE}'"
fi
cd - > /dev/null

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
success "OS X TO ARM CROSS COMPILER BUILT IN '${CROSS_DIR}'"
success "Total Size: "`du -hc ${CROSS_DIR} | grep 'total' | awk '{ print $1; }'`
exit 0
