#!/bin/bash
set -e

sudo apt install git build-essential autoconf automake cmake libtool rename tar -y

# Set cpu count
cpu_count="$(grep -c processor /proc/cpuinfo 2>/dev/null)"
if [ -z "$cpu_count" ]; then
  echo "Unable to determine cpu count, set default 1"
  cpu_count=1
fi

build_dir=$(pwd)/libheif_build
prefix=$build_dir/dist

export LDFLAGS="-L$prefix/lib -pipe"
export CPPFLAGS="-I$prefix/include -fPIC"
export CFLAGS="-I$prefix/include -mtune=generic -O3 -fPIC -pipe"
export CXXFLAGS="${CFLAGS}"

export PKG_CONFIG_PATH=$prefix/lib/pkgconfig

rm -rf $prefix

mkdir -p $build_dir
mkdir -p $prefix

cd $build_dir
git -C x265_git pull || git clone https://bitbucket.org/multicoreware/x265_git
rm -rf x265_build
mkdir -p x265_build
cd x265_build
cmake -DCMAKE_INSTALL_PREFIX:PATH=$prefix -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 -DENABLE_SHARED=1 -DENABLE_CLI=0 -DENABLE_TESTS=0 ../x265_git/source
make -j$cpu_count && make install
cd ..

git -C aom pull || git clone -b v3.5.0 --depth 1 https://aomedia.googlesource.com/aom 
rm -rf aom_build
mkdir -p aom_build
cd aom_build
cmake -DCMAKE_INSTALL_PREFIX:PATH=$prefix -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=0 -DENABLE_DOCS=0 -DENABLE_EXAMPLES=0 -DENABLE_TESTDATA=0 -DENABLE_TESTS=0 -DENABLE_TOOLS=0 ../aom
make -j$cpu_count && make install
cd ..

git -C libde265 pull || git clone https://github.com/strukturag/libde265.git
cd libde265
./autogen.sh
./configure --prefix=$prefix --disable-shared --enable-static --disable-dec265 --disable-sherlock265
make -j$cpu_count && make install
cd ..

git -C libheif pull || git clone https://github.com/strukturag/libheif
cd libheif
./autogen.sh
./configure --prefix=$prefix --enable-shared
make LDFLAGS="-Wl,-rpath '-Wl,\$\$ORIGIN'" -j$cpu_count && make install
cd ..

cd $prefix/lib
# Delete links
find -type l -delete

rm *.*a

mv libheif.so.1.15.1 libheif.so

tar -czvf libheif-linux-x64.tar.gz *.*
