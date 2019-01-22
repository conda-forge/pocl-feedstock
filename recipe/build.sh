mkdir build
cd build

EXTRA_HOST_CLANG_FLAGS=""

if [ "$(uname)" == "Darwin" ]; then
  OPENCL_LIBRARIES=""
  LINKER_FLAG=""
  EXTRA_HOST_LD_FLAGS="-dead_strip_dylibs"
else  # linux for now
  OPENCL_LIBRARIES="-L${PREFIX}/lib;OpenCL"
  LINKER_FLAG=""
  EXTRA_HOST_LD_FLAGS="--as-needed"
fi

if [[ "$cxx_compiler" == "gxx" ]]; then
  EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -L$BUILD_PREFIX/$HOST/sysroot/usr/lib"
  EXTRA_HOST_CLANG_FLAGS="-I$BUILD_PREFIX/$HOST/sysroot/usr/include"
fi

# avoid linking to libLLVM and libclang in build prefix. These are from the compiler package by anaconda
rm -rf $BUILD_PREFIX/lib/libLLVM*.a $BUILD_PREFIX/lib/libclang*.a
rm -rf $BUILD_PREFIX/include/llvm $BUILD_PREFIX/include/llvm-c
rm -rf $BUILD_PREFIX/include/clang $BUILD_PREFIX/include/clang-c

if [[ "$(uname)" == "Darwin" || "$c_compiler" == "toolchain_c" ]]; then
  export CC=$PREFIX/bin/clang
  export CXX=$PREFIX/bin/clang++
fi

cmake \
  -D CMAKE_BUILD_TYPE="Release" \
  -D CMAKE_INSTALL_PREFIX="${PREFIX}" \
  -D POCL_INSTALL_ICD_VENDORDIR="${PREFIX}/etc/OpenCL/vendors" \
  -D LLVM_CONFIG="${PREFIX}/bin/llvm-config" \
  -D INSTALL_OPENCL_HEADERS="off" \
  -D KERNELLIB_HOST_CPU_VARIANTS=distro \
  -D OPENCL_LIBRARIES="${OPENCL_LIBRARIES}" \
  $LINKER_FLAG \
  -D EXTRA_HOST_LD_FLAGS="${EXTRA_HOST_LD_FLAGS}" \
  -D EXTRA_HOST_CLANG_FLAGS="${EXTRA_HOST_CLANG_FLAGS}" \
  -D CMAKE_INSTALL_LIBDIR=lib \
  ..

make -j 8
make check
make install


if [[ "$(uname)" == "Darwin" ]]; then
    cd ../ocl_icd_wrapper
    autoreconf -i
    chmod +x configure
    ./configure
    make LDFLAGS+="-L$PREFIX/lib -lpocl"

    mkdir -p ${PREFIX}/lib
    mkdir -p ${PREFIX}/etc/OpenCL/vendors

    cp .libs/libocl_icd_wrapper.0.dylib ${PREFIX}/lib/libocl_icd_wrapper_pocl.dylib
    ${INSTALL_NAME_TOOL} -id ${PREFIX}/lib/libocl_icd_wrapper_pocl.dylib ${PREFIX}/lib/libocl_icd_wrapper_pocl.dylib
    ${OTOOL} -L ${PREFIX}/lib/libocl_icd_wrapper_pocl.dylib

    echo ${PREFIX}/lib/libocl_icd_wrapper_pocl.dylib > ${PREFIX}/etc/OpenCL/vendors/pocl.icd

    # For backwards compatibility
    ln -s ${PREFIX}/lib/libpocl.dylib ${PREFIX}/lib/libOpenCL.2.dylib
fi
