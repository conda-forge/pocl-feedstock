mkdir build
cd build

cmake \
  -D CMAKE_INSTALL_PREFIX="${PREFIX}" \
  -D POCL_INSTALL_ICD_VENDORDIR="${PREFIX}/etc/OpenCL/vendors" \
  -D LLVM_CONFIG="${PREFIX}/bin/llvm-config" \
  -D HAVE_CLOCK_GETTIME=1 \
  -D KERNELLIB_HOST_CPU_VARIANTS=distro \
  -D OPENCL_LIBRARIES="-L${PREFIX}/lib;OpenCL" \
  -D EXTRA_HOST_LD_FLAGS="-Wl,--as-needed" \
  ..

make -j 8
make install
