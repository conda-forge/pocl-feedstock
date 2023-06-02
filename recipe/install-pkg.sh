mkdir -p $PREFIX/lib/pocl

if [[ "$PKG_NAME" == "pocl-cuda" ]]; then
  mv build/libpocl-devices-cuda.so $PREFIX/lib/pocl/
elif [[ "$PKG_NAME" == "pocl-cpu-minimal" ]]; then
  mv build/libpocl-devices-basic.so $PREFIX/lib/pocl/
elif [[ "$PKG_NAME" == "pocl-cpu" ]]; then
  mv build/libpocl-devices-pthread.so $PREFIX/lib/pocl/
fi
