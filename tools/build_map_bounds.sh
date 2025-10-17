#!/bin/bash
set -e

#!/bin/sh
# MOVED: original content archived to tools/_removed/map_bounds_extractor/
echo "map_bounds_extractor helper moved to tools/_removed/map_bounds_extractor/"
exit 0
WORKDIR="/home/wowcore"
cd "$WORKDIR"
rm -rf map_bounds_build
mkdir -p map_bounds_build
cd map_bounds_build

# Compiler flags
CFLAGS="-std=c11 -O2 -DVERSION=\"0.1\" -DHAVE_FSEEKO=1 -DHAVE_OFF_T=1 -D_FILE_OFFSET_BITS=64 -I$WORKDIR/azerothcore/deps/libmpq/libmpq"
CFLAGS="-std=c11 -O2 -DVERSION=\"0.1\" -DHAVE_FSEEKO=1 -DHAVE_OFF_T=1 -D_FILE_OFFSET_BITS=64 -I$WORKDIR/azerothcore/deps/libmpq/libmpq -I$WORKDIR/azerothcore/deps/libmpq"
CXXFLAGS="-std=c++17 -O2 -DVERSION=\"0.1\" -DHAVE_FSEEKO=1 -DHAVE_OFF_T=1 -D_FILE_OFFSET_BITS=64 -I$WORKDIR/azerothcore/src/tools/vmap4_extractor -I$WORKDIR/azerothcore/deps/libmpq/libmpq -I$WORKDIR/azerothcore/deps/libmpq -I$WORKDIR/azerothcore/deps/g3dlite/include"

echo "Compiling libmpq C sources..."
eval "gcc $CFLAGS -c $WORKDIR/azerothcore/deps/libmpq/libmpq/mpq.c -o mpq.o"
for f in huffman.c common.c extract.c wave.c; do
  eval "gcc $CFLAGS -c $WORKDIR/azerothcore/deps/libmpq/libmpq/$f -o ${f%.c}.o"
done
# also compile explode.c which provides pkzip decompression
eval "gcc $CFLAGS -c $WORKDIR/azerothcore/deps/libmpq/libmpq/explode.c -o explode.o" || true

echo "Compiling vmap4 extractor C++ sources..."
# compile selected C++ sources in the vmap4_extractor directory (exclude tools with a main like vmapexport.cpp)
VMAP_SRCS=(mpq_libmpq.cpp adtfile.cpp wdtfile.cpp model.cpp wmo.cpp dbcfile.cpp gameobject_extract.cpp)
for s in "${VMAP_SRCS[@]}"; do
  cpp="$WORKDIR/azerothcore/src/tools/vmap4_extractor/$s"
  obj=$(basename "$s" .cpp).o
  echo "Compiling $cpp -> $obj"
  eval "g++ $CXXFLAGS -c $cpp -o $obj"
done

# compile g3dlite sources (they provide G3D::Matrix/Quat used by model.cpp)
G3D_OBJS=()
for gcpp in $WORKDIR/azerothcore/deps/g3dlite/source/*.cpp; do
  gobj=$(basename "$gcpp" .cpp).o
  echo "Compiling $gcpp -> $gobj"
  eval "g++ $CXXFLAGS -I$WORKDIR/azerothcore/deps/g3dlite/include -c $gcpp -o $gobj"
  G3D_OBJS+=("$gobj")
done

# compile main
eval "g++ $CXXFLAGS -c $WORKDIR/map_bounds_extractor.cpp -o extractor.o"

# link (explicit list to avoid duplicates)
OBJ_LIST=(extractor.o mpq_libmpq.o adtfile.o wdtfile.o model.o wmo.o dbcfile.o gameobject_extract.o mpq.o huffman.o common.o extract.o wave.o explode.o)
for g in "${G3D_OBJS[@]}"; do OBJ_LIST+=("$g"); done

echo "Linking: ${OBJ_LIST[*]}"
g++ -std=c++17 -O2 -o $WORKDIR/map_bounds_extractor ${OBJ_LIST[*]} -lz -lm -lbz2 -pthread

echo "Build finished: $WORKDIR/map_bounds_extractor"
