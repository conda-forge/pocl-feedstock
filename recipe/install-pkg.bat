@echo on
SetLocal EnableDelayedExpansion

set "PREFIX=%LIBRARY_PREFIX%"
set "HOST=x86_64-pc-windows-msvc"

cd build/pkgs
mkdir -p %PREFIX%/bin/pocl
mkdir -p %PREFIX%/share/pocl

if "%PKG_NAME%" == "pocl-cuda" (
  mv pocl-devices-cuda.dll %PREFIX%/bin/pocl/
  mv kernel-nvptx64-*.bc %PREFIX%/share/pocl/
  mv cuda %PREFIX%/share/pocl/
)
if "%PKG_NAME%" == "pocl-cpu-minimal" (
  mv pocl-devices-basic.dll %PREFIX%/bin/pocl/
  ls kernel-%HOST%*.bc
  mv kernel-%HOST%*.bc %PREFIX%/share/pocl/
)
if "%PKG_NAME%" == "pocl-cpu" (
  mv pocl-devices-pthread.dll %PREFIX%/bin/pocl/
)
if "%PKG_NAME%" == "pocl-remote" (
  mv pocl-devices-remote.dll %PREFIX%/bin/pocl/
fi
