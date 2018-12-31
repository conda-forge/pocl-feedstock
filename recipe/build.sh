mkdir build
cd build

if [ "$(uname)" == "Darwin" ]; then
  OPENCL_LIBRARIES=""
  INSTALL_OPENCL_HEADERS=ON
  LINKER_FLAG=""
  EXTRA_HOST_LD_FLAGS="-dead_strip_dylibs"
else  # linux for now
  OPENCL_LIBRARIES="-L${PREFIX}/lib;OpenCL"
  INSTALL_OPENCL_HEADERS=OFF
  LINKER_FLAG="-D LINK_COMMAND=$LD"
  EXTRA_HOST_LD_FLAGS="--as-needed"
  export LDFLAGS="$LDFLAGS -L$BUILD_PREFIX/$HOST/sysroot/usr/lib"
  export CFLAGS="$CFLAGS -I$BUILD_PREFIX/$HOST/sysroot/usr/include"
  export CXXFLAGS="$CXXFLAGS -I$BUILD_PREFIX/$HOST/sysroot/usr/include"
fi

if [[ "$(uname)" == "Darwin" || "$c_compiler" == "toolchain_c" ]]; then
  export CC=$PREFIX/bin/clang
  export CXX=$PREFIX/bin/clang++
fi

cmake \
  -D CMAKE_BUILD_TYPE="Release" \
  -D CMAKE_INSTALL_PREFIX="${PREFIX}" \
  -D POCL_INSTALL_ICD_VENDORDIR="${PREFIX}/etc/OpenCL/vendors" \
  -D LLVM_CONFIG="${PREFIX}/bin/llvm-config" \
  -D INSTALL_OPENCL_HEADERS="${INSTALL_OPENCL_HEADERS}" \
  -D KERNELLIB_HOST_CPU_VARIANTS=distro \
  -D OPENCL_LIBRARIES="${OPENCL_LIBRARIES}" \
  $LINKER_FLAG \
  -D EXTRA_HOST_LD_FLAGS="${EXTRA_HOST_LD_FLAGS}" \
  ..

make -j 8
make check
make install
