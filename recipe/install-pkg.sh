set -x

cd build/pkgs
mkdir -p $PREFIX/lib/pocl

if [[ "$PKG_NAME" == "pocl-cuda" ]]; then
  mv libpocl-devices-cuda.so $PREFIX/lib/pocl/
  mv kernel-nvptx64-*.bc $PREFIX/share/pocl/
  mv cuda $PREFIX/share/pocl/
elif [[ "$PKG_NAME" == "pocl-cpu-minimal" ]]; then
  mv libpocl-devices-basic.so $PREFIX/lib/pocl/
  ls kernel-${HOST:0:10}*.bc
  mv kernel-${HOST:0:10}*.bc $PREFIX/share/pocl/
elif [[ "$PKG_NAME" == "pocl-cpu" ]]; then
  mv libpocl-devices-pthread.so $PREFIX/lib/pocl/
elif [[ "$PKG_NAME" == "pocl-remote" ]]; then
  mv libpocl-devices-remote.so $PREFIX/lib/pocl/
fi
