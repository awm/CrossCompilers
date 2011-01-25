#!/bin/bash
# Copyright (c) 2011 Andrew MacIsaac
# License: MIT

source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# set binutils, gcc, mingw, and w32api versions
BINUTILS_VERSION=2.19.1
GCC_VERSION=4.2.4
MINGW_VERSION=3.15.2
W32API_VERSION=3.13
GDB_VERSION=6.8

# set CFLAGS
BINUTILS_CFLAGS="-O2 -fno-exceptions"
W32API_CFLAGS="-O2 -mms-bitfields -march=i386"
MINGW_CFLAGS="${W32API_CFLAGS}"
GCC_CFLAGS="-O2 -fomit-frame-pointer"
GDB_CFLAGS="${GCC_CFLAGS}"

# target system
TARGET_SYSTEM=i386-mingw32

# host system
HOST_SYSTEM=${TARGET_SYSTEM}

# finished cross-compiler root directory
CROSS_DIR="`pwd`/install"

# set package names
BINUTILS_PACKAGE=binutils-${BINUTILS_VERSION}
GCC_PACKAGE=gcc-${GCC_VERSION}
MINGW_PACKAGE=mingwrt-${MINGW_VERSION}-mingw32
W32API_PACKAGE=w32api-${W32API_VERSION}-mingw32
GDB_PACKAGE=gdb-${GDB_VERSION}

# set download file names
BINUTILS_FILE=${BINUTILS_PACKAGE}.tar.bz2
GCC_FILE=gcc-core-${GCC_VERSION}.tar.bz2
GXX_FILE=gcc-g++-${GCC_VERSION}.tar.bz2
MINGW_FILE=${MINGW_PACKAGE}-src.tar.gz
W32API_FILE=${W32API_PACKAGE}-src.tar.gz
GCC_27067_PATCH_FILE=bug27067-gcc4_2.patch
GDB_FILE=${GDB_PACKAGE}.tar.bz2

# set download URLs
BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/${BINUTILS_FILE}"
GCC_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GCC_FILE}"
GXX_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GXX_FILE}"
MINGW_URL="http://downloads.sourceforge.net/mingw/${MINGW_FILE}"
W32API_URL="http://downloads.sourceforge.net/mingw/${W32API_FILE}"
GCC_27067_PATCH_URL="http://gcc.gnu.org/bugzilla/attachment.cgi?id=12927"
GDB_URL="http://ftp.gnu.org/gnu/gdb/${GDB_FILE}"

### BUILD PROCESS ###
status "BUILDING WINDOWS COMPILER...."
check_prerequesites

# create some needed directories
status "Creating directories...."
# first check if they exist, then create them if they don't
cond_mkdir "${CROSS_DIR}"
cond_mkdir "${DL_DIR}"
cond_mkdir "${SRC_DIR}"
cond_mkdir "${SRC_DIR}/w32api"
cond_mkdir "${CROSS_DIR}/mingw"
cond_mkdir "${BUILD_DIR}/${BINUTILS_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${MINGW_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${W32API_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GDB_PACKAGE}"

# download the needed packages
status "Downloading packages (if needed)...."
download "${BINUTILS_URL}"
download "${MINGW_URL}"
download "${W32API_URL}"
download "${GCC_URL}"
download "${GXX_URL}"
download "${GCC_27067_PATCH_URL}" "${GCC_27067_PATCH_FILE}"
download "${GDB_URL}"

# only extract binutils if needed
cond_extract "" "${BINUTILS_PACKAGE}" "${BINUTILS_FILE}"

# determine build system
BUILD_SYSTEM=`${SRC_DIR}/${BINUTILS_PACKAGE}/config.guess`

# build binutils
status "Building ${BINUTILS_PACKAGE}...."
cd ${BUILD_DIR}/${BINUTILS_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${BINUTILS_PACKAGE}/configure		\
						--prefix=${CROSS_DIR}			\
						--with-sysroot=${CROSS_DIR}		\
						--build=${BUILD_SYSTEM}			\
						--host=${HOST_SYSTEM}			\
						--target=${TARGET_SYSTEM}		\
						--with-gcc						\
						--with-gnu-as					\
						--with-gnu-ld					\
						--disable-nls					\
						--disable-shared				||
	abort "Failed to configure ${BINUTILS_PACKAGE}"
[ -f ld/ld-new.exe ] || make CFLAGS="${BINUTILS_CFLAGS}" || abort "Failed to build ${BINUTILS_PACKAGE}"
[ -x ${CROSS_DIR}/bin/ld.exe ] || make install || abort "Failed to install ${BINUTILS_PACKAGE}"
cd - > /dev/null

# only extract mingw-runtime if not done
cond_extract "" "${MINGW_PACKAGE}" "${MINGW_FILE}"

# only copy mingw-runtime includes if not done
if [ ! -f "${CROSS_DIR}/include/_mingw.h" ]; then
	# copy mingw-runtime includes
	status "Copying ${MINGW_PACKAGE} include files...."
	cp -R ${SRC_DIR}/${MINGW_PACKAGE}/include ${CROSS_DIR}/ || abort "Failed to copy ${MINGW_PACKAGE} includes"
fi

# only extract w32api if not done
cond_extract "" "${W32API_PACKAGE}" "${W32API_FILE}"

# only copy w32api includes if not done
if [ ! -f "${CROSS_DIR}/include/w32api.h" ]; then
	# copy w32api includes
	status "Copying ${W32API_PACKAGE} include files...."
	cp -R ${SRC_DIR}/${W32API_PACKAGE}/include ${CROSS_DIR}/ || abort "Failed to copy ${W32API_PACKAGE} includes"
fi

# only extract gcc if not done
cond_extract "" "${GCC_PACKAGE}" "${GCC_FILE}"

# only extract g++ if not done
cond_extract "" "${GCC_PACKAGE}/libstdc++-v3" "${GXX_FILE}"

# patch gcc bug #27067 (needed to cross-compile wxWidgets)
status "Patching GCC for bug #27067 (needed to cross-compile wxWidgets)...."
cd ${SRC_DIR}/${GCC_PACKAGE}
DO_PATCH="`grep 'i386_pe_decorate_assembler_name' gcc/config/i386/cygming.h`"
if [ -z "${DO_PATCH}" ]; then
	# run patch
	patch -p0 < ../../${DL_DIR}/${GCC_27067_PATCH_FILE} || abort "Failed to apply patch"
fi
cd - > /dev/null

# fix includes if not done
status "Fixing includes...."
if [ ! -L "${SRC_DIR}/w32api/include" ]; then
	ln -sf ${CROSS_DIR}/include ${SRC_DIR}/w32api/include || abort "Failed to create 'w32api/include' link"
fi
if [ ! -L "${CROSS_DIR}/mingw/include" ]; then
	ln -sf ${CROSS_DIR}/include ${CROSS_DIR}/mingw/include || abort "Failed to create 'mingw/include' link"
fi

status "Building ${W32API_PACKAGE}...."
cd ${BUILD_DIR}/${W32API_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${W32API_PACKAGE}/configure	\
						--prefix=${CROSS_DIR}		\
						--build=${BUILD_SYSTEM}		\
						--host=${HOST_SYSTEM}		\
						--target=${TARGET_SYSTEM}	||
	abort "Failed to configure ${W32API_PACKAGE}"
[ -f lib/libkernel32.a ] || make CFLAGS="${W32API_CFLAGS}" || abort "Failed to build ${W32API_PACKAGE}"
[ -f ${CROSS_DIR}/lib/libkernel32.a ] || make install || abort "Failed to install ${W32API_PACKAGE}"
cd - > /dev/null

status "Building ${MINGW_PACKAGE}...."
cd ${BUILD_DIR}/${MINGW_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${MINGW_PACKAGE}/configure		\
						--prefix=${CROSS_DIR}		\
						--build=${BUILD_SYSTEM}		\
						--host=${HOST_SYSTEM}		\
						--target=${TARGET_SYSTEM}	||
	abort "Failed to configure ${MINGW_PACKAGE}"
[ -f mingwm10.dll ] || make CFLAGS="${MINGW_CFLAGS}" || abort "Failed to build ${MINGW_PACKAGE}"
[ -f ${CROSS_DIR}/bin/mingwm10.dll ] || make install || abort "Failed to install ${MINGW_PACKAGE}"
cd - > /dev/null

# build gcc/g++
status "Building '${GCC_PACKAGE}'...."
cd ${BUILD_DIR}/${GCC_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${GCC_PACKAGE}/configure			\
						--prefix=${CROSS_DIR}			\
						--with-sysroot=${CROSS_DIR}		\
						--build=${BUILD_SYSTEM}			\
						--host=${HOST_SYSTEM}			\
						--target=${TARGET_SYSTEM}		\
						--with-gcc						\
						--with-gnu-as					\
						--with-gnu-ld					\
						--disable-nls					\
						--enable-languages=c,c++		\
						--enable-threads=win32			\
						--enable-sjlj-exceptions		||
	abort "Failed to configure '${GCC_PACKAGE}'"
[ -f gcc/g++.exe ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
[ -d "${TARGET_SYSTEM}/libstdc++-v3" ] || make CFLAGS="${GCC_CFLAGS}" all-target-libstdc++-v3 || abort "Failed to build 'libstdc++'"
[ -x "${CROSS_DIR}/bin/g++.exe" ] || make install || abort "Failed to install '${GCC_PACKAGE}'"
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
						--build=${BUILD_SYSTEM}		\
						--host=${HOST_SYSTEM}		\
						--target=${TARGET_SYSTEM}	\
						--with-gcc					\
						--with-gnu-as				\
						--with-gnu-ld				\
						--disable-nls				\
						--enable-languages=c,c++	\
						--enable-threads=win32		\
						--enable-sjlj-exceptions	||
	abort "Failed to configure '${GDB_PACKAGE}'"
[ -f "gdb/gdb.exe" ] || make CFLAGS="${GDB_CFLAGS}" || abort "Failed to build '${GDB_PACKAGE}'"
[ -x "${CROSS_DIR}/bin/gdb.exe" ] || make install || abort "Failed to install '${GDB_PACKAGE}'"
cd - > /dev/null

# remove symlinks from install directory
status "Removing symbolic links from installation directory...."
rm -Rf "${CROSS_DIR}/mingw"

# all done
success "WINDOWS COMPILER BUILT IN '${CROSS_DIR}'"
success "Total Size: "`du -hc ${CROSS_DIR} | grep 'total' | awk '{ print $1; }'`
exit 0
