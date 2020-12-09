if [[ "$target_platform" == linux* ]]; then
  sed -i 's/add_subdirectory("matrix1")//g' examples/CMakeLists.txt
  sed -i 's/"-lm",//g' lib/CL/devices/common.c
fi

rm -rf build
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

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" ]]; then
  mv $BUILD_PREFIX/bin/llvm-config $PREFIX/bin/llvm-config
  LLVM_TOOLS_PREFIX="$BUILD_PREFIX"
else
  LLVM_TOOLS_PREFIX="$PREFIX"
fi

if [[ "$target_platform" == linux-aarch64 ]]; then
  AARCH64_CPUS="generic;cortex-a35;cortex-a53;cortex-a55;cortex-a57;cortex-a65;cortex-a72;cortex-a73;cortex-a75;cortex-a76"
  AARCH64_CPUS="${AARCH64_CPUS};cyclone;exynos-m3;exynos-m4;exynos-m5;falkor;kryo;neoverse-e1;neoverse-n1;saphira"
  AARCH64_CPUS="${AARCH64_CPUS};thunderx;thunderx2t99;thunderxt81;thunderxt83;thunderxt88;tsv110"
  CMAKE_ARGS="$CMAKE_ARGS -DKERNELLIB_HOST_CPU_VARIANTS='${AARCH64_CPUS}' -DLLC_HOST_CPU=cortex-a35 -DCLANG_MARCH_FLAG='-mcpu='"
elif [[ "$target_platform" == linux-ppc64le ]]; then
  CMAKE_ARGS="$CMAKE_ARGS -DKERNELLIB_HOST_CPU_VARIANTS='pwr8;pwr9;generic' -DCLANG_MARCH_FLAG='-mcpu='"
elif [[ "$target_platform" == osx-arm64 ]]; then
  CMAKE_ARGS="$CMAKE_ARGS -DKERNELLIB_HOST_CPU_VARIANTS='cyclone' -DCLANG_MARCH_FLAG='-mcpu=' -DLLC_HOST_CPU=cyclone"
fi

if [[ "$enable_cuda" == "True" ]]; then
  CMAKE_ARGS="$CMAKE_ARGS -DENABLE_CUDA=ON -DCUDA_TOOLKIT_ROOT_DIR=$CUDA_HOME"
  LDFLAGS="$LDFLAGS -L$CUDA_HOME/lib64/stubs"
fi

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
  -D LLVM_HOST_TARGET=$HOST \
  -D LLVM_BINDIR=$BUILD_PREFIX/bin \
  ${CMAKE_ARGS} \
  ..

make -j ${CPU_COUNT} VERBOSE=1
# install needs to come first for the pocl.icd to be found
make install

if [[ "$enable_cuda" == "True" ]]; then
  # Don't package the cuda package in pocl package
  mv $PREFIX/lib/pocl/libpocl-devices-cuda.so .
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" != "1" ]]; then
# Workaround for https://github.com/KhronosGroup/OpenCL-ICD-Loader/issues/104
sed -i.bak "s@ocl-vendors@ocl-vendors/@g" CTestCustom.cmake

SKIP_TESTS="dummy"
if [[ "$target_platform" == "linux-ppc64le" ]]; then
  # Following tests fail on CI with 'LLVM ERROR: Do not know how to split the result of this operator!'
  # On a power8 machine, they fail with the following error on LLVM<10. Looks like a harmless test failure
  # where LLVM doesn't conform to strict OpenCL standards on rounding to integers for values close to
  # the max of the integer type
  # 'FAIL: convert_int16_sat_rtn(double16) - sample#: 7 element#: 0 original: 2147483648 expected: 0x7ffffffe actual: 0x7fffffff'
  SKIP_TESTS="$SKIP_TESTS|kernel/test_convert_type_4|kernel/test_convert_type_8|kernel/test_convert_type_16"
  # Following tests pass locally on power8, but segfaults on CI
  SKIP_TESTS="$SKIP_TESTS|kernel/test_convert_type_2|kernel/test_sampler_address_clamp|kernel/test_image_query_funcs"
fi

export POCL_DEVICES=pthread

ctest -E "$SKIP_TESTS"

# Can't run cuda tests without a GPU
# if [[ "$enable_cuda" == "True" ]]; then
#   POCL_DEVICES=cuda ctest -L cuda
# fi
fi

# For backwards compatibility
if [[ "$target_platform" == osx-64 ]]; then
  ln -s $PREFIX/lib/libpocl.dylib $PREFIX/lib/libOpenCL.2.dylib
fi
