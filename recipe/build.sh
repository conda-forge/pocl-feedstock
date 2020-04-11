mkdir build
cd build

# Info needed to report in pocl release testing
if [[ "$target_platform" == linux* ]]; then
    cat /proc/cpuinfo || true
elif [[ "$target_platform" == osx* ]]; then
    system_profiler SPHardwareDataType || true
fi

EXTRA_HOST_CLANG_FLAGS=""
OPENCL_LIBRARIES="${PREFIX}/lib/libOpenCL${SHLIB_EXT}"

if [[ "$cxx_compiler" == "gxx" ]]; then
  EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -nodefaultlibs -L$BUILD_PREFIX/$HOST/sysroot/usr/lib"
  EXTRA_HOST_CLANG_FLAGS="-I$BUILD_PREFIX/$HOST/sysroot/usr/include"
fi

EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -Wl,-rpath,$PREFIX/lib"

if [[ "$target_platform" == osx* ]]; then
  export SDKROOT=$CONDA_BUILD_SYSROOT
  export CC=$PREFIX/bin/clang
  export CXX=$PREFIX/bin/clang++
fi

export OCL_ICD_DEBUG=15

cmake \
  -D CMAKE_BUILD_TYPE="Release" \
  -D CMAKE_INSTALL_PREFIX="${PREFIX}" \
  -D CMAKE_PREFIX_PATH="${PREFIX}" \
  -D POCL_INSTALL_ICD_VENDORDIR="${PREFIX}/etc/OpenCL/vendors" \
  -D LLVM_CONFIG="${PREFIX}/bin/llvm-config" \
  -D INSTALL_OPENCL_HEADERS="off" \
  -D KERNELLIB_HOST_CPU_VARIANTS=distro \
  -D OPENCL_LIBRARIES="${OPENCL_LIBRARIES}" \
  -D EXTRA_HOST_LD_FLAGS="${EXTRA_HOST_LD_FLAGS}" \
  -D EXTRA_HOST_CLANG_FLAGS="${EXTRA_HOST_CLANG_FLAGS}" \
  -D CMAKE_INSTALL_LIBDIR=lib \
  -D ENABLE_ICD=on \
  ..

make -j ${CPU_COUNT} VERBOSE=1
# install needs to come first for the pocl.icd to be found
make install
echo "$PREFIX/lib/libpocl$SHLIB_EXT" > ${PREFIX}/etc/OpenCL/vendors/pocl.icd
make check

# For backwards compatibility
if [[ "$target_platform" == osx* ]]; then
    ln -s $PREFIX/lib/libpocl.dylib $PREFIX/lib/libOpenCL.2.dylib
fi
