@echo on
SetLocal EnableDelayedExpansion

mkdir build
cd build

set "CUDA_HOME=%LIBRARY_PREFIX%"
set "PREFIX=%LIBRARY_PREFIX%"
set "HOST=x86_64-pc-windows-msvc"

if "%enable_cuda%" == "True" (
  set "CMAKE_ARGS=%CMAKE_ARGS% -DENABLE_CUDA=ON -DCUDAToolkit_ROOT=%CUDA_HOME% -DCUDA_INCLUDE_DIRS=%CUDA_HOME%/include -DCUDA_TOOLKIT_INCLUDE=%CUDA_HOME%/include"
)

if "%enable_cuda%" == "True" (
  set "CMAKE_ARGS=%CMAKE_ARGS% -DCUDA_CUDART_LIBRARY=%PREFIX%/lib/libcudart.so -DCUDA_TOOLKIT_ROOT_DIR_INTERNAL=%CUDA_HOME%"
)

copy %LIBRARY_LIB%\zstd.lib %LIBRARY_LIB%\zstd.dll.lib

cmake -G Ninja ^
  -D CMAKE_BUILD_TYPE="Release" ^
  -D CMAKE_INSTALL_PREFIX="%PREFIX%" ^
  -D CMAKE_PREFIX_PATH="%PREFIX%" ^
  -D POCL_INSTALL_ICD_VENDORDIR="%PREFIX%/etc/OpenCL/vendors" ^
  -D LLVM_CONFIG="%PREFIX%/bin/llvm-config.exe" ^
  -D INSTALL_OPENCL_HEADERS="off" ^
  -D KERNELLIB_HOST_CPU_VARIANTS=distro ^
  -D OPENCL_LIBRARIES="%PREFIX%/lib/OpenCL.lib" ^
  -D CMAKE_INSTALL_LIBDIR=lib ^
  -D ENABLE_ICD=on ^
  -D LLVM_HOST_TARGET=%HOST% ^
  -D LLC_TRIPLE=%HOST% ^
  -D LLVM_BINDIR=%BUILD_PREFIX%/Library/bin ^
  -D OPENCL_H="%PREFIX%/include/CL/opencl.h" ^
  -D OPENCL_HPP="%PREFIX%/include/CL/opencl.hpp" ^
  -D OCL_ICD_INCLUDE_DIRS="%PREFIX%/include" ^
  -D ENABLE_REMOTE_SERVER=off ^
  -D ENABLE_REMOTE_CLIENT=off ^
  -D ENABLE_LOADBALE_DRIVERS=on ^
  -D STATIC_LLVM=ON ^
  -D LLVM_LINK_TEST=ON ^
  -D CLANG_LINK_TEST=ON ^
  %CMAKE_ARGS% ^
  ..

if errorlevel 1 exit 1

ninja -j %CPU_COUNT%
if errorlevel 1 exit 1

ninja install
if errorlevel 1 exit 1

del %LIBRARY_LIB%\zstd.dll.lib

set POCL_DEVICES=cpu

REM Setting this will produce extra output that confuses the test result parser
REM set POCL_DEBUG=1

set "SKIP_TESTS=kernel/test_halfs_loopvec|kernel/test_halfs_cbs|kernel/test_printf_vectors_halfn_loopvec"
set "SKIP_TESTS=%SKIP_TESTS%|kernel/test_printf_vectors_halfn_cbs|regression/test_rematerialized_alloca_load_with_outside_pr_users"
set "SKIP_TESTS=%SKIP_TESTS%|runtime/test_large_buf|workgroup/conditional_barrier_dynamic"
set "SKIP_TESTS=%SKIP_TESTS%|regression/test_issue_1525"

ctest -E "%SKIP_TESTS%|remote" --output-on-failure
if errorlevel 1 exit 1

REM Can't run cuda tests without a GPU
REM if "%$enable_cuda%" == "True" (
REM   set POCL_DEVICES=cuda
REM   ctest -L cuda
REM )

REM move files that are in individual pkgs
mkdir pkgs
move %PREFIX%\\bin\\pocl\\pocl-devices-*.dll pkgs\\
move %PREFIX%\\share\\pocl\\kernel-*.bc pkgs\\
if "%enable_cuda%" == "True" (
  move %PREFIX%\\share\\pocl\\cuda pkgs\\
)
