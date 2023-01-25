if [[ "$target_platform" == linux* ]]; then
  sed -i.bak 's/add_subdirectory("matrix1")//g' examples/CMakeLists.txt
fi

sed -i.bak 's/"-lm",//g' lib/CL/devices/common.c
sed -i.bak 's/-dynamiclib -w -lm/-dynamiclib -w/g' CMakeLists.txt

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

EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -nodefaultlibs"

if [[ "$target_platform" == linux-* ]]; then
  EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -L$BUILD_PREFIX/$HOST/sysroot/usr/lib"
  EXTRA_HOST_CLANG_FLAGS="-I$BUILD_PREFIX/$HOST/sysroot/usr/include"
elif [[ "$target_platform" == osx-* ]]; then
  # We are using `-nodefaultlibs` to avoid the need to have the macOS SDK
  # on the user machine.
  # However, there's a bug in the apple provided linker that doesn't let you
  # link with no dynamic libraries. (rdar://39514191)
  # This is patched by the linker packaged in conda, but when the environment is
  # not activated, clang tries to use the system linker.
  # Adding -B $PREFIX/libexec/pocl makes clang look there for the linker first.
  EXTRA_HOST_LD_FLAGS="$EXTRA_HOST_LD_FLAGS -undefined dynamic_lookup -B $PREFIX/libexec/pocl"
  mkdir -p $PREFIX/libexec/pocl
  ln -sf $PREFIX/bin/ld $PREFIX/libexec/pocl/ld
fi

if [[ "$target_platform" == linux-ppc64le ]]; then
  EXTRA_HOST_CLANG_FLAGS="${EXTRA_HOST_CLANG_FLAGS} -faltivec-src-compat=mixed -Wno-deprecated-altivec-src-compat"
fi

if [[ "$CONDA_BUILD_CROSS_COMPILATION" == "1" && "${CMAKE_CROSSCOMPILING_EMULATOR:-}" == "" ]]; then
  rm $PREFIX/bin/llvm-config
  cp $BUILD_PREFIX/bin/llvm-config $PREFIX/bin/llvm-config
  if [[ "$target_platform" == osx-* ]]; then
    install_name_tool -add_rpath $BUILD_PREFIX/lib $PREFIX/bin/llvm-config
  fi
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
  CMAKE_ARGS="$CMAKE_ARGS -DKERNELLIB_HOST_CPU_VARIANTS='pwr8;pwr9;generic' -DLLC_HOST_CPU=pwr8 -DCLANG_MARCH_FLAG='-mcpu='"
elif [[ "$target_platform" == osx-arm64 ]]; then
  CMAKE_ARGS="$CMAKE_ARGS -DKERNELLIB_HOST_CPU_VARIANTS='cyclone' -DCLANG_MARCH_FLAG='-mcpu=' -DLLC_HOST_CPU=cyclone"
fi

if [[ "$target_platform" != "linux-aarch64" || "${CI}" != "travis" ]]; then
  CMAKE_ARGS="$CMAKE_ARGS -DCMAKE_VERBOSE_MAKEFILE=1"
fi

if [[ "$enable_cuda" == "True" ]]; then
  CMAKE_ARGS="$CMAKE_ARGS -DENABLE_CUDA=ON -DCUDA_TOOLKIT_ROOT_DIR=$CUDA_HOME -DCUDA_INCLUDE_DIRS=$CUDA_HOME/include -DCUDA_TOOLKIT_INCLUDE=$CUDA_HOME/include"
  CMAKE_ARGS="$CMAKE_ARGS -DCUDA_CUDART_LIBRARY=$CUDA_HOME/lib64/libcudart.so -DCUDA_TOOLKIT_ROOT_DIR_INTERNAL=$CUDA_HOME"
  LDFLAGS="$LDFLAGS -L$CUDA_HOME/lib64/stubs"
fi

set

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
  -D OPENCL_H="${PREFIX}/include/CL/opencl.h" \
  -D OPENCL_HPP="${PREFIX}/include/CL/opencl.hpp" \
  -D OCL_ICD_INCLUDE_DIRS="${PREFIX}/include" \
  ${CMAKE_ARGS} \
  ..

make -j ${CPU_COUNT} -k
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

  export POCL_DEVICES=pthread

  # Setting this will produce extra output that confuses the test result parser
  # export POCL_DEBUG=1

  if [[ "$target_platform" == osx-* ]]; then
    # Check that we don't need the SDK
    unset SDKROOT
    unset CONDA_BUILD_SYSROOT
  fi

  if [[ "$CI" == "travis" ]]; then
    # pocl/hwloc seems to mistake the number of cores
    # in the weird travis-ci virtual CPU setting and
    # the test require POCL_AFFINITY to be set which
    # schedules the i-th thread to i-th core and fails.
    SKIP_TESTS="$SKIP_TESTS|EinsteinToolkit_SubDev"
  fi

  if [[ $target_platform == "linux-aarch64" ]]; then
    # These tests fail on aarch64
    SKIP_TESTS="$SKIP_TESTS|test_printf_vectors|test_printf_vectors_ulong"
  fi

  ctest -E "$SKIP_TESTS" --output-on-failure

  # Can't run cuda tests without a GPU
  # if [[ "$enable_cuda" == "True" ]]; then
  #   POCL_DEVICES=cuda ctest -L cuda
  # fi
fi

# For backwards compatibility
if [[ "$target_platform" == osx-64 ]]; then
  ln -s $PREFIX/lib/libpocl.dylib $PREFIX/lib/libOpenCL.2.dylib
fi
