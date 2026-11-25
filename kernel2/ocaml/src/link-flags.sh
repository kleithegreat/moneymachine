#!/bin/sh
# Prints the C flags (`cflags`) or the link flags (`libs`, as -cclib arguments, for the executables only) that bring Lean's static runtime, Engine, and pinned MPFR/GMP into
# an OCaml link. MM2_ENGINE_LIB is the absolute path of Lake's libengine_Engine.a; the toolchain is the `lean` on PATH.
set -eu
prefix=$(lean --print-prefix)
case $1 in
  cflags) echo "(-I $prefix/include -O2 -fPIC)" ;;
  libs)
    printf '('
    for flag in "$MM2_ENGINE_LIB" -L"$prefix/lib/lean" -L"$prefix/lib" -Wl,--start-group -lInit -lleanrt -Wl,--end-group \
      -lmpfr -lgmp -luv -Wl,-Bstatic -lc++ -lc++abi -lunwind -Wl,-Bdynamic -lpthread -ldl -lm; do
      printf ' -cclib "%s"' "$flag"
    done
    echo ' )'
    ;;
esac
