#!/bin/bash
source "../../../cross_compilers.shlib"

### CONFIGURATION ###

# set binutils, gcc, newlib versions
BINUTILS_VERSION=2.20.1
GCC_VERSION=4.3.3
GMP_VERSION=4.2.4
MPFR_VERSION=2.3.2
KERNEL_VERSION=2.6.31.13
GLIBC_VERSION=2.9

# set CFLAGS
BINUTILS_CFLAGS=""
GCC_CFLAGS=""
GLIBC_CFLAGS=""

# target system
TARGET_SYSTEM=arm-angstrom-linux-gnueabi

# finished cross-compiler root directory
CROSS_DIR=${CROSS_BASE}/arm-angstrom

# set package names
BINUTILS_PACKAGE=binutils-${BINUTILS_VERSION}
GCC_PACKAGE=gcc-${GCC_VERSION}
GMP_PACKAGE=gmp-${GMP_VERSION}
MPFR_PACKAGE=mpfr-${MPFR_VERSION}
KERNEL_PACKAGE=linux-${KERNEL_VERSION}
GLIBC_PACKAGE=glibc-${GLIBC_VERSION}
GLIBC_PORTS_PACKAGE=glibc-ports-${GLIBC_VERSION}
GLIBC_LIBIDN_PACKAGE=glibc-libidn-${GLIBC_VERSION}

# set download file names
BINUTILS_FILE=${BINUTILS_PACKAGE}.tar.bz2
GCC_FILE=gcc-${GCC_VERSION}.tar.bz2
GMP_FILE=${GMP_PACKAGE}.tar.bz2
MPFR_FILE=${MPFR_PACKAGE}.tar.bz2
KERNEL_FILE=${KERNEL_PACKAGE}.tar.bz2
GLIBC_FILE=${GLIBC_PACKAGE}.tar.bz2
GLIBC_PORTS_FILE=${GLIBC_PORTS_PACKAGE}.tar.bz2
GLIBC_LIBIDN_FILE=${GLIBC_LIBIDN_PACKAGE}.tar.bz2
GLIBC_GENERIC_BITS_SELECT_FILE=generic-bits_select.h
GLIBC_GENERIC_BITS_TIME_FILE=generic-bits_time.h
GLIBC_GENERIC_BITS_TYPES_FILE=generic-bits_types.h
GLIBC_GENERIC_BITS_TYPESIZES_FILE=generic-bits_typesizes.h

# set download URLs
BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/${BINUTILS_FILE}"
GCC_URL="http://ftp.gnu.org/gnu/gcc/${GCC_PACKAGE}/${GCC_FILE}"
GMP_URL="ftp://ftp.gnu.org/gnu/gmp/${GMP_FILE}"
MPFR_URL="http://www.mpfr.org/mpfr-${MPFR_VERSION}/${MPFR_FILE}"
KERNEL_URL="http://www.kernel.org/pub/linux/kernel/v2.6/${KERNEL_FILE}"
GLIBC_URL="ftp://ftp.gnu.org/pub/gnu/glibc/${GLIBC_FILE}"
GLIBC_PORTS_URL="ftp://ftp.gnu.org/pub/gnu/glibc/${GLIBC_PORTS_FILE}"
GLIBC_LIBIDN_URL="ftp://ftp.gnu.org/pub/gnu/glibc/${GLIBC_LIBIDN_FILE}"
GLIBC_GENERIC_BITS_SELECT_URL="http://gitorious.org/gumstix-oe/mainline/blobs/raw/overo/recipes/glibc/glibc-2.4/${GLIBC_GENERIC_BITS_SELECT_FILE}"
GLIBC_GENERIC_BITS_TIME_URL="http://gitorious.org/gumstix-oe/mainline/blobs/raw/overo/recipes/glibc/glibc-2.4/${GLIBC_GENERIC_BITS_TIME_FILE}"
GLIBC_GENERIC_BITS_TYPES_URL="http://gitorious.org/gumstix-oe/mainline/blobs/raw/overo/recipes/glibc/glibc-2.4/${GLIBC_GENERIC_BITS_TYPES_FILE}"
GLIBC_GENERIC_BITS_TYPESIZES_URL="http://gitorious.org/gumstix-oe/mainline/blobs/raw/overo/recipes/glibc/glibc-2.4/${GLIBC_GENERIC_BITS_TYPESIZES_FILE}"

### BUILD PROCESS ###
status "BUILDING OS X TO ANGSTROM LINUX CROSS COMPILER...."
check_prerequesites

# create some needed directories
status "Creating directories...."
# first check if they exist, then create them if they don't
cond_mkdir "${CROSS_DIR}"
cond_mkdir "${DL_DIR}/angstrom-glibc"
cond_mkdir "${SRC_DIR}"
cond_mkdir "${BUILD_DIR}/${BINUTILS_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${KERNEL_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GLIBC_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GLIBC_PACKAGE}-bootstrap"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}"
cond_mkdir "${BUILD_DIR}/${GCC_PACKAGE}-bootstrap"
cond_mkdir "${CROSS_DIR}/usr"

# download the needed packages
status "Downloading packages (if needed)...."
download "${BINUTILS_URL}"
download "${GCC_URL}"
download "${GMP_URL}"
download "${MPFR_URL}"
download "${KERNEL_URL}"
download "${GLIBC_URL}"
download "${GLIBC_PORTS_URL}"
download "${GLIBC_LIBIDN_URL}"
download "${GLIBC_GENERIC_BITS_SELECT_URL}" "angstrom-glibc/${GLIBC_GENERIC_BITS_SELECT_FILE}"
download "${GLIBC_GENERIC_BITS_TIME_URL}" "angstrom-glibc/${GLIBC_GENERIC_BITS_TIME_FILE}"
download "${GLIBC_GENERIC_BITS_TYPES_URL}" "angstrom-glibc/${GLIBC_GENERIC_BITS_TYPES_FILE}"
download "${GLIBC_GENERIC_BITS_TYPESIZES_URL}" "angstrom-glibc/${GLIBC_GENERIC_BITS_TYPESIZES_FILE}"

# download the patches
status "Downloading patches (if needed)...."
download_patches $BINUTILS_PACKAGE binutils.patches
download_patches $KERNEL_PACKAGE linux-libc-headers.patches
download_patches $GMP_PACKAGE gmp.patches
download_patches $GCC_PACKAGE gcc.patches
download_patches $GLIBC_PACKAGE glibc.patches

# only extract binutils if needed
cond_extract "" "${BINUTILS_PACKAGE}" "${BINUTILS_FILE}"

# patch binutils
apply_patches $BINUTILS_PACKAGE

# determine build system
BUILD_SYSTEM=`${SRC_DIR}/${BINUTILS_PACKAGE}/config.guess`

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
						--disable-werror            \
						--enable-install-libbfd     ||
	abort "Failed to configure ${BINUTILS_PACKAGE}"
[ -f ld/ld-new ] || make CFLAGS="${BINUTILS_CFLAGS}" || abort "Failed to build ${BINUTILS_PACKAGE}"
[ -x ${CROSS_DIR}/bin/${TARGET_SYSTEM}-ld ] || make install || abort "Failed to install ${BINUTILS_PACKAGE}"
[ -f ${CROSS_DIR}/lib/libiberty_pic.a ] || install -m 0644 libiberty/pic/libiberty.a ${CROSS_DIR}/lib/libiberty_pic.a
cd - > /dev/null

# add new cross directory to the PATH
export PATH=$PATH:$CROSS_DIR

# only extract kernel source if needed
cond_extract "" "${KERNEL_PACKAGE}" "${KERNEL_FILE}"

# patch kernel
apply_patches $KERNEL_PACKAGE

# sync kernel build directory, and install kernel headers
status "Preparing and installing ${KERNEL_PACKAGE}...."
rsync -a ${SRC_DIR}/${KERNEL_PACKAGE}/ ${BUILD_DIR}/${KERNEL_PACKAGE}
cd ${BUILD_DIR}/${KERNEL_PACKAGE}
[ -f .config ] || make allnoconfig ARCH=arm || abort "Failed to prepare ${KERNEL_PACKAGE}"
[ -f ${CROSS_DIR}/usr/include/linux/kernel.h ] || make headers_install INSTALL_HDR_PATH=${CROSS_DIR}/usr ARCH=arm || abort "Failed to install ${KERNEL_PACKAGE}"
rm -f ${CROSS_DIR}/usr/include/scsi/scsi.h
cd - > /dev/null

# only extract gmp if needed
cond_extract "" "${GMP_PACKAGE}" "${GMP_FILE}"

# patch gmp
apply_patches $GMP_PACKAGE

# only extract mpfr if needed
cond_extract "" "${MPFR_PACKAGE}" "${MPFR_FILE}"

# # only extract glibc if needed
# cond_extract "" "${GLIBC_PACKAGE}" "${GLIBC_FILE}"
# 
# # only extract glibc-ports if needed
# cond_extract "" "${GLIBC_PORTS_PACKAGE}" "${GLIBC_PORTS_FILE}"
# 
# # only extract glibc-libidn if needed
# cond_extract "" "${GLIBC_LIBIDN_PACKAGE}" "${GLIBC_LIBIDN_FILE}"
# 
# # prepare glibc
# status "Preparing and installing ${GLIBC_PACKAGE}...."
# cd ${SRC_DIR}/${GLIBC_PACKAGE}
# ln -sf ../${GLIBC_PORTS_PACKAGE} ports || abort "Failed to create ports link"
# ln -sf ../${GLIBC_LIBIDN_PACKAGE} libidn || abort "Failed to create libidn link"
# # vvv the following is adapted from the glibc bitbake recipe: http://gitorious.org/gumstix-oe/mainline/blobs/overo/recipes/glibc/glibc_2.9.bb vvv
# rm -Rf ports/sysdeps/unix/sysv/linux/arm/linuxthreads
# ln -sf nptl ports/sysdeps/unix/sysv/linux/arm/linuxthreads
# cp -f nptl/sysdeps/pthread/bits/sigthread.h ports/sysdeps/unix/sysv/linux/arm/bits/
# cp -f sysdeps/unix/sysv/linux/i386/bits/wchar.h ports/sysdeps/unix/sysv/linux/arm/bits/
# cp -f sysdeps/wordsize-32/bits/wordsize.h ports/sysdeps/unix/sysv/linux/arm/bits/
# cp -f ../../${DL_DIR}/angstrom-glibc/generic-bits_select.h ports/sysdeps/unix/sysv/linux/arm/bits/select.h
# cp -f ../../${DL_DIR}/angstrom-glibc/generic-bits_types.h ports/sysdeps/unix/sysv/linux/arm/bits/types.h
# cp -f ../../${DL_DIR}/angstrom-glibc/generic-bits_typesizes.h ports/sysdeps/unix/sysv/linux/arm/bits/typesizes.h
# cp -f ../../${DL_DIR}/angstrom-glibc/generic-bits_time.h ports/sysdeps/unix/sysv/linux/arm/bits/time.h
# for i in bits/*.h; do
#     F=`basename $i`
#     [ "$F" = "local_lim.h" ] && continue
#     [ "$F" = "errno.h" ] && continue
#     test -e ports/sysdeps/unix/sysv/linux/arm/bits/$F ||
#         test -e ports/sysdeps/arm/bits/$F ||
#         test -e sysdeps/unix/sysv/linux/bits/$F ||
#         test -e sysdeps/ieee754/bits/$F ||
#         cp $i ports/sysdeps/unix/sysv/linux/arm/bits/
# done
# rm -f ports/sysdeps/unix/sysv/linux/arm/bits/libc-lock.h
# rm -f ports/sysdeps/unix/sysv/linux/arm/bits/fenv.h
# rm -f ports/sysdeps/unix/sysv/linux/arm/bits/utmp.h
# sed -ie 's:/var/db/nscd:/var/run/nscd:' nscd/nscd.h
# sed -ie 's,{ (exit 1); exit 1; }; },{ (exit 0); }; },g' configure
# # ^^^^^^
# cd - > /dev/null
# cd ${BUILD_DIR}/${GLIBC_PACKAGE}-bootstrap
# # vvv the following is adapted from the glibc bitbake recipe: http://gitorious.org/gumstix-oe/mainline/blobs/overo/recipes/glibc/glibc-initial.inc vvv
# [ -f Makefile ] ||
#   ../../${SRC_DIR}/${GLIBC_PACKAGE}/configure                 \
#                       --prefix=${CROSS_DIR}                   \
#                       --host=${TARGET_SYSTEM}                 \
#                       --build=${BUILD_SYSTEM}                 \
#                         --without-cvs                           \
#                         --disable-sanity-checks                 \
#                         --with-headers=${CROSS_DIR}/usr/include \
#                         --enable-hacker-mode                    ||
#   abort "Failed to configure ${GLIBC_PACKAGE}-bootstrap"
# make cross-compiling=yes includedir=${CROSS_DIR}/usr/include prefix=${CROSS_DIR} install-bootstrap-headers=yes install-headers || abort "Failed to install ${GLIBC_PACKAGE}-bootstrap headers"
# # make csu/subdir_lib || abort "Failed to build ${GLIBC_PACKAGE}-bootstrap csu/subdir_lib"
# mkdir -p ${CROSS_DIR}/usr/include/gnu
# touch ${CROSS_DIR}/usr/include/gnu/stubs.h
# cp -f ../../${SRC_DIR}/${GLIBC_PACKAGE}/include/features.h ${CROSS_DIR}/usr/include/gnu/features.h
# if [ -e bits/stdio_lim.h ]; then
#     cp -f bits/stdio_lim.h ${CROSS_DIR}/usr/include/bits/stdio_lim.h
# fi
# # mkdir -p ${CROSS_DIR}/lib
# # install -m 644 csu/crt[1in].o ${D}${libdir}
# # ${CC} -nostdlib -nostartfiles -shared -x c /dev/null -o ${D}${libdir}/libc.so
# cd - > /dev/null

# only extract gcc if not done
cond_extract "" "${GCC_PACKAGE}" "${GCC_FILE}"

# patch gcc
apply_patches $GCC_PACKAGE

# create library links
status "Creating numeric library links...."
cd ${SRC_DIR}/${GCC_PACKAGE}
ln -sf ../${GMP_PACKAGE} gmp || abort "Failed to create GMP link"
ln -sf ../${MPFR_PACKAGE} mpfr || abort "Failed to create MPFR link"
cd - > /dev/null

status "Building bootstrapping compiler...."
cd ${BUILD_DIR}/${GCC_PACKAGE}-bootstrap
[ -f Makefile ] ||
  ../../${SRC_DIR}/${GCC_PACKAGE}/configure         \
                      --prefix=${CROSS_DIR}         \
                      --with-sysroot=${CROSS_DIR}   \
                      --target=${TARGET_SYSTEM}     \
                      --disable-nls                 \
                      --enable-shared               \
                      --disable-threads             \
                      --disable-multilib            \
                      --enable-languages=c          \
                      --disable-libmudflap          \
                      --disable-libgomp             \
                      --disable-libssp              \
                      --with-float=soft             ||
  abort "Failed to configure bootstrapping compiler"
[ -f "gcc/gcc" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build bootstrapping compiler"
[ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-gcc" ] || make install || abort "Failed to install bootstrapping compiler"
cd - > /dev/null

# status "Building ${NEWLIB_PACKAGE}...."
# cd ${BUILD_DIR}/${NEWLIB_PACKAGE}
# [ -f Makefile ] ||
#   ../../${SRC_DIR}/${NEWLIB_PACKAGE}/configure    \
#                       --prefix=${CROSS_DIR}       \
#                       --target=${TARGET_SYSTEM}   \
#                       --enable-interwork          \
#                       --disable-shared            \
#                       --with-float=soft           \
#                       --enable-multilib           ||
#   abort "Failed to configure ${NEWLIB_PACKAGE}"
# [ -f "${TARGET_SYSTEM}/newlib/libc.a" ] || make CFLAGS="${NEWLIB_CFLAGS}" || abort "Failed to build ${NEWLIB_PACKAGE}"
# [ -f "${CROSS_DIR}/${TARGET_SYSTEM}/lib/libc.a" ] || make install || abort "Failed to install ${NEWLIB_PACKAGE}"
# cd - > /dev/null
# 
# if [ ${ENABLE_CXX} -ne 0 ]; then
#   # only extract g++ if not done
#   cond_extract "" "${GCC_PACKAGE}/libstdc++-v3" "${GXX_FILE}"
# 
#   # build gcc/g++
#   status "Building '${GCC_PACKAGE}'...."
#   cd ${BUILD_DIR}/${GCC_PACKAGE}
#   [ -f Makefile ] ||
#       ../../${SRC_DIR}/${GCC_PACKAGE}/configure       \
#                           --prefix=${CROSS_DIR}       \
#                           --with-sysroot=${CROSS_DIR} \
#                           --target=${TARGET_SYSTEM}   \
#                           --with-gcc                  \
#                           --with-gnu-as               \
#                           --with-gnu-ld               \
#                           --disable-nls               \
#                           --enable-languages=c,c++    \
#                           --enable-interwork          \
#                           --with-float=soft           \
#                           --with-newlib               \
#                           --enable-multilib           \
#                           --disable-threads           ||
#       abort "Failed to configure '${GCC_PACKAGE}'"
#   [ -f "gcc/g++" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
#   [ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-g++" ] || make install || abort "Failed to install '${GCC_PACKAGE}'"
# else
#   # build gcc
#   status "Building '${GCC_PACKAGE}'...."
#   cd ${BUILD_DIR}/${GCC_PACKAGE}
#   [ -f Makefile ] ||
#       ../../${SRC_DIR}/${GCC_PACKAGE}/configure       \
#                           --prefix=${CROSS_DIR}       \
#                           --with-sysroot=${CROSS_DIR} \
#                           --target=${TARGET_SYSTEM}   \
#                           --with-gcc                  \
#                           --with-gnu-as               \
#                           --with-gnu-ld               \
#                           --disable-nls               \
#                           --enable-languages=c        \
#                           --enable-interwork          \
#                           --with-float=soft           \
#                           --with-newlib               \
#                           --enable-multilib           \
#                           --disable-threads           ||
#       abort "Failed to configure '${GCC_PACKAGE}'"
#   [ -f "gcc/gcc" ] || make CFLAGS="${GCC_CFLAGS}" || abort "Failed to build '${GCC_PACKAGE}'"
#   make install || abort "Failed to install '${GCC_PACKAGE}'"
# fi
# cd - > /dev/null
# 
# # only extract gdb if not done
# cond_extract "" "${GDB_PACKAGE}" "${GDB_FILE}"
# 
# # build gdb
# status "Building '${GDB_PACKAGE}'...."
# cd ${BUILD_DIR}/${GDB_PACKAGE}
# [ -f Makefile ] ||
#   ../../${SRC_DIR}/${GDB_PACKAGE}/configure       \
#                       --prefix=${CROSS_DIR}       \
#                       --with-sysroot=${CROSS_DIR} \
#                       --target=${TARGET_SYSTEM}   \
#                       --disable-nls               \
#                       --enable-interwork          \
#                       --enable-multilib           \
#                       --with-float=soft           ||
#   abort "Failed to configure '${GDB_PACKAGE}'"
# [ -f "gdb/gdb" ] || make CFLAGS="${GDB_CFLAGS}" || abort "Failed to build '${GDB_PACKAGE}'"
# [ -x "${CROSS_DIR}/bin/${TARGET_SYSTEM}-gdb" ] || make install || abort "Failed to install '${GDB_PACKAGE}'"
# cd - > /dev/null
# 
# # all done
# success "OS X TO ARM CROSS COMPILER BUILT IN '${CROSS_DIR}'"
# success "Total Size: "`du -hc ${CROSS_DIR} | grep 'total' | awk '{ print $1; }'`
# exit 0
