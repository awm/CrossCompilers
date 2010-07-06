#!/bin/bash
source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# set whether of not to enable C++ support
ENABLE_CXX=0

# set binutils, gcc, newlib versions
BINUTILS_VERSION=2.19.1
GCC_VERSION=4.4.1
GMP_VERSION=4.3.1
MPFR_VERSION=2.4.1
NEWLIB_VERSION=1.17.0
NASM_VERSION=2.07
GDB_VERSION=6.8

# set CFLAGS
BINUTILS_CFLAGS=""
GCC_CFLAGS=""
GMP_CFLAGS=""
MPFR_CFLAGS="${GMP_CFLAGS}"
NEWLIB_CFLAGS=""
NEWLIB_CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections"
NASM_CFLAGS=""
GDB_CFLAGS=""

# target system
TARGET_SYSTEM=i686-elf

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/x86

# set package names
BINUTILS_PACKAGE=binutils-${BINUTILS_VERSION}
GCC_PACKAGE=gcc-${GCC_VERSION}
GXX_PACKAGE=g++-${GCC_VERSION}
GMP_PACKAGE=gmp-${GMP_VERSION}
MPFR_PACKAGE=mpfr-${MPFR_VERSION}
NEWLIB_PACKAGE=newlib-${NEWLIB_VERSION}
NASM_PACKAGE=nasm-${NASM_VERSION}
GDB_PACKAGE=gdb-${GDB_VERSION}

# set download file names
BINUTILS_FILE=${BINUTILS_PACKAGE}.tar.bz2
GCC_FILE=gcc-core-${GCC_VERSION}.tar.bz2
GXX_FILE=gcc-g++-${GCC_VERSION}.tar.bz2
GMP_FILE=${GMP_PACKAGE}.tar.bz2
MPFR_FILE=${MPFR_PACKAGE}.tar.bz2
NEWLIB_FILE=${NEWLIB_PACKAGE}.tar.gz
NASM_FILE=${NASM_PACKAGE}.tar.bz2
GDB_FILE=${GDB_PACKAGE}.tar.bz2

# set download URLs
BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/${BINUTILS_FILE}"
GCC_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GCC_FILE}"
GXX_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GXX_FILE}"
GMP_URL="ftp://ftp.gnu.org/gnu/gmp/${GMP_FILE}"
MPFR_URL="http://www.mpfr.org/mpfr-current/${MPFR_FILE}"
NEWLIB_URL="ftp://sources.redhat.com/pub/newlib/${NEWLIB_FILE}"
NASM_URL="http://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/${NASM_FILE}"
GDB_URL="http://ftp.gnu.org/gnu/gdb/${GDB_FILE}"

### BUILD PROCESS ###
status "BUILDING OS X TO x86 CROSS COMPILER...."
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
if [ ${ENABLE_CXX} -ne 0 ]; then
	download "${GXX_URL}"
fi
download "${GMP_URL}"
download "${MPFR_URL}"
download "${NEWLIB_URL}"
download "${NASM_URL}"
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
						--disable-nls				||
	abort "Failed to configure ${BINUTILS_PACKAGE}"
[ -f ld/ld-new ] || make CFLAGS="${BINUTILS_CFLAGS}" || abort "Failed to build ${BINUTILS_PACKAGE}"
[ -x ${CROSS_DIR}/bin/${TARGET_SYSTEM}-ld ] || make install || abort "Failed to install ${BINUTILS_PACKAGE}"
cd - > /dev/null

# only extract gmp if needed
cond_extract "" "${GMP_PACKAGE}" "${GMP_FILE}"

# only extract mpfr if needed
cond_extract "" "${MPFR_PACKAGE}" "${MPFR_FILE}"

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
cd - > /dev/null

status "Building bootstrapping compiler...."
cd ${BUILD_DIR}/${GCC_PACKAGE}-bootstrap
[ -f Makefile ] ||
	../../${SRC_DIR}/${GCC_PACKAGE}/configure			\
						--prefix=${CROSS_DIR}			\
						--with-sysroot=${CROSS_DIR}		\
						--target=${TARGET_SYSTEM}		\
						--with-gcc						\
						--with-gnu-as					\
						--with-gnu-ld					\
						--disable-nls					\
						--enable-languages=c			\
						--with-newlib					\
						--disable-threads				\
						--disable-shared				\
						--without-headers				||
	abort "Failed to configure bootstrapping compiler"
[ -f "gcc/gcc" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build bootstrapping compiler"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-gcc" ] || make install || abort "Failed to install bootstrapping compiler"
export PATH="${PATH}:${CROSS_DIR}/bin"
cd - > /dev/null

status "Building ${NEWLIB_PACKAGE}...."
cd ${BUILD_DIR}/${NEWLIB_PACKAGE}
[ -f Makefile ] ||
	../../${SRC_DIR}/${NEWLIB_PACKAGE}/configure			\
						--prefix=${CROSS_DIR}				\
						--target=${TARGET_SYSTEM}			\
						--with-gcc							\
						--with-gnu-as						\
						--with-gnu-ld						\
						--disable-newlib-supplied-syscalls	\
						--disable-shared					||
	abort "Failed to configure ${NEWLIB_PACKAGE}"
[ -f "${TARGET_SYSTEM}/newlib/libc.a" ] ||
	make CFLAGS="${NEWLIB_CFLAGS}" CFLAGS_FOR_TARGET="${NEWLIB_CFLAGS_FOR_TARGET}" ||
	abort "Failed to build ${NEWLIB_PACKAGE}"
[ -f "${CROSS_DIR}/${TARGET_SYSTEM}/lib/libc.a" ] || make install || abort "Failed to install ${NEWLIB_PACKAGE}"
cd - > /dev/null

status "Creating symbolic library links...."
if [ ! -L "${CROSS_DIR}/usr/lib/libc.a" ]; then
	mkdir -p ${CROSS_DIR}/usr/lib || abort "Failed to create ${CROSS_DIR}/usr/lib"
	ln -svf ${CROSS_DIR}/${TARGET_SYSTEM}/lib/*.a ${CROSS_DIR}/usr/lib || abort "Failed to create *.a links"
	ln -svf ${CROSS_DIR}/${TARGET_SYSTEM}/lib/*.o ${CROSS_DIR}/usr/lib || abort "Failed to create *.o links"
fi

if [ ${ENABLE_CXX} -ne 0 ]; then
	# only extract g++ if not done
	cond_extract "" "${GCC_PACKAGE}/libstdc++-v3" "${GXX_FILE}"
	
	# patch g++
	status "Patching libstdc++-v3...."
	cd ${SRC_DIR}/${GCC_PACKAGE}
	patch -p1 -N < ../../config-fix.patch || abort "Failed to patch 'libstdc++-v3'"
	cd - > /dev/null

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
							--disable-threads			\
							--disable-shared			||
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
							--disable-threads			\
							--disable-shared			||
		abort "Failed to configure '${GCC_PACKAGE}'"
	[ -f "gcc/gcc" ] || make all-gcc CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
	make install-gcc || abort "Failed to install '${GCC_PACKAGE}'"
fi
cd - > /dev/null

# only extract nasm if not done
cond_extract "" "${NASM_PACKAGE}" "${NASM_FILE}"
[ -d "${BUILD_DIR}/${NASM_PACKAGE}" ] || mv ${SRC_DIR}/${NASM_PACKAGE} ${BUILD_DIR}/${NASM_PACKAGE} || abort "Failed to move ${NASM_PACKAGE} source"

# build nasm
status "Building '${NASM_PACKAGE}'...."
cd ${BUILD_DIR}/${NASM_PACKAGE}
[ -f Makefile ] || ./configure --prefix=${CROSS_DIR} || abort "Failed to configure '${NASM_PACKAGE}'"
[ -x "nasm" ] || make CFLAGS="${NASM_CFLAGS}" || abort "Failed to build '${NASM_PACKAGE}'"
[ -x "${CROSS_DIR}/bin/nasm" ] || make install || abort "Failed to install '${NASM_PACKAGE}'"
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
						--disable-nls				||
	abort "Failed to configure '${GDB_PACKAGE}'"
[ -f "gdb/gdb" ] || make CFLAGS="${GDB_CFLAGS}" || abort "Failed to build '${GDB_PACKAGE}'"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-gdb" ] || make install || abort "Failed to install '${GDB_PACKAGE}'"
cd - > /dev/null

# all done
success "OS X TO x86 CROSS COMPILER BUILT IN '${CROSS_DIR}'"
success "Total Size: "`du -hc ${CROSS_DIR} | grep 'total' | awk '{ print $1; }'`
exit 0
