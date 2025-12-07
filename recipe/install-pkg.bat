@echo on
SetLocal EnableDelayedExpansion

set "PREFIX=%LIBRARY_PREFIX%"
set "HOST=x86_64-pc-windows-msvc"

cd build\pkgs
mkdir -p %PREFIX%\bin\pocl
mkdir -p %PREFIX%\share\pocl

dir

if "%PKG_NAME%" == "pocl-cuda" (
  move pocl-devices-cuda.dll %PREFIX%\bin\pocl\
  move kernel-nvptx64-*.bc %PREFIX%\share\pocl\
  move cuda %PREFIX%\share\pocl\
)
if "%PKG_NAME%" == "pocl-cpu-minimal" (
  move pocl-devices-basic.dll %PREFIX%\bin\pocl\
  move kernel-%HOST%*.bc %PREFIX%\share\pocl\
)
if "%PKG_NAME%" == "pocl-cpu" (
  move pocl-devices-pthread.dll %PREFIX%\bin\pocl\
)
if "%PKG_NAME%" == "pocl-remote" (
  move pocl-devices-remote.dll %PREFIX%\bin\pocl\
fi
