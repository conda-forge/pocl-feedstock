set "PREFIX=%LIBRARY_PREFIX%"

cd build/pkgs
mkdir -p %PREFIX%/lib/pocl

if "%PKG_NAME%" == "pocl-cuda" (
  mv libpocl-devices-cuda.dll %PREFIX%/lib/pocl/
  mv kernel-nvptx64-*.bc %PREFIX%/share/pocl/
  mv cuda %PREFIX%/share/pocl/
)
if "%PKG_NAME%" == "pocl-cpu-minimal" (
  mv libpocl-devices-basic.dll %PREFIX%/lib/pocl/
  ls kernel-${HOST:0:10}*.bc
  mv kernel-${HOST:0:10}*.bc %PREFIX%/share/pocl/
)
if "%PKG_NAME%" == "pocl-cpu" (
  mv libpocl-devices-pthread.dll %PREFIX%/lib/pocl/
)
if "%PKG_NAME%" == "pocl-remote" (
  mv libpocl-devices-remote.dll %PREFIX%/lib/pocl/
fi
