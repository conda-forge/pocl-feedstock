mkdir build
cd build

set "CUDA_HOME=%LIBRARY_PREFIX%"
set "PREFIX=%LIBRARY_PREFIX%"
set "HOST=x86_64-pc-windows-msvc"

if "%enable_cuda%" == "True" (
  set "CMAKE_ARGS=%CMAKE_ARGS% -DENABLE_CUDA=ON -DCUDAToolkit_ROOT=%CUDA_HOME% -DCUDA_INCLUDE_DIRS=%CUDA_HOME%/include -DCUDA_TOOLKIT_INCLUDE=%CUDA_HOME%/include"
  set "CMAKE_ARGS=%CMAKE_ARGS% -DCUDA_CUDART_LIBRARY=%PREFIX%/lib/libcudart.so -DCUDA_TOOLKIT_ROOT_DIR_INTERNAL=%CUDA_HOME%"
)

cmake -G Ninja ^
  -D CMAKE_BUILD_TYPE="Release" ^
  -D CMAKE_INSTALL_PREFIX="%PREFIX%" ^
  -D CMAKE_PREFIX_PATH="%PREFIX%" ^
  -D POCL_INSTALL_ICD_VENDORDIR="%PREFIX%/etc/OpenCL/vendors" ^
  -D LLVM_CONFIG="%PREFIX%/bin/llvm-config" ^
  -D INSTALL_OPENCL_HEADERS="off" ^
  -D KERNELLIB_HOST_CPU_VARIANTS=distro ^
  -D OPENCL_LIBRARIES="%PREFIX%/lib/OpenCL.lib" ^
  -D CMAKE_INSTALL_LIBDIR=lib ^
  -D ENABLE_ICD=on ^
  -D LLVM_HOST_TARGET=%HOST% ^
  -D LLVM_BINDIR=%BUILD_PREFIX%/Library/bin ^
  -D OPENCL_H="%PREFIX%/include/CL/opencl.h" ^
  -D OPENCL_HPP="%PREFIX%/include/CL/opencl.hpp" ^
  -D OCL_ICD_INCLUDE_DIRS="%PREFIX%/include" ^
  -D LLVM_SPIRV=%PREFIX%/bin/llvm-spirv-%LLVM_VERSION_MAJOR% ^
  -D ENABLE_REMOTE_SERVER=on ^
  -D ENABLE_REMOTE_CLIENT=on ^
  -D ENABLE_LOADBALE_DRIVERS=on ^
  %CMAKE_ARGS% ^
  ..

ninja -j %CPU_COUNT%
ninja install

set POCL_DEVICES=cpu

REM Setting this will produce extra output that confuses the test result parser
REM set POCL_DEBUG=1

ctest -E "remote" --output-on-failure

REM Can't run cuda tests without a GPU
REM if "%$enable_cuda%" == "True" (
REM   set POCL_DEVICES=cuda
REM   ctest -L cuda
REM )

# move files that are in individual pkgs
mkdir pkgs
move %PREFIX%/lib/pocl/pocl-devices-*.dll pkgs/
move %PREFIX%/share/pocl/kernel-*.bc pkgs/
if "%enable_cuda%" == "True" (
  move %PREFIX%/share/pocl/cuda pkgs/
)
