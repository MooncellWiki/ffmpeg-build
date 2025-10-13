#!/usr/bin/env bash

set -eu

cd $(dirname $0)
BASE_DIR=$(pwd)

source common.sh

if [ ! -e $FFMPEG_TARBALL ]
then
	curl -s -L -O $FFMPEG_TARBALL_URL
fi

: ${ARCH?}

OUTPUT_DIR=artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-linux-gnu

DPKG_ARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
LD_DIR=/usr/lib/$DPKG_ARCH
INCLUDE_DIR=/usr/include

sudo mv ${LD_DIR}/libmp3lame.so ${LD_DIR}/libmp3lame.so.bak
sudo mv ${LD_DIR}/libmp3lame.so.0 ${LD_DIR}/libmp3lame.so.0.bak
sudo mv ${LD_DIR}/libmp3lame.so.0.0.0 ${LD_DIR}/libmp3lame.so.0.0.0.bak

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

case $ARCH in
    x86_64)
        FFMPEG_CONFIGURE_FLAGS+=(
            --extra-cflags="-I$INCLUDE_DIR"
            --extra-ldflags="-L$LD_DIR"
        )
        ;;
    i686)
        FFMPEG_CONFIGURE_FLAGS+=(
            --cc="gcc -m32"
            --extra-cflags="-I$INCLUDE_DIR"
            --extra-ldflags="-L$LD_DIR"
        )
        ;;
    arm64)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=aarch64-linux-gnu-
            --target-os=linux
            --arch=aarch64
            --extra-cflags="-I$INCLUDE_DIR"
            --extra-ldflags="-L$LD_DIR"
        )
        ;;
    arm*)
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=arm-linux-gnueabihf-
            --target-os=linux
            --arch=arm
        )
        case $ARCH in
            armv7-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv7-a
                    --extra-cflags="-I$INCLUDE_DIR"
                    --extra-ldflags="-L$LD_DIR"
                )
                ;;
            armv8-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv8-a
                    --extra-cflags="-I$INCLUDE_DIR"
                    --extra-ldflags="-L$LD_DIR"
                )
                ;;
            armhf-rpi2)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a7
                    --extra-cflags="-fPIC -mcpu=cortex-a7 -mfloat-abi=hard -mfpu=neon-vfpv4 -mvectorize-with-neon-quad -I$INCLUDE_DIR"
                    --extra-ldflags="-L$LD_DIR"
                )
                ;;
            armhf-rpi3)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a53
                    --extra-cflags="-fPIC -mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mvectorize-with-neon-quad -I$INCLUDE_DIR"
                    --extra-ldflags="-L$LD_DIR"
                )
                ;;
        esac
        ;;
    *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
esac

cd $BUILD_DIR
tar --strip-components=1 -xf $BASE_DIR/$FFMPEG_TARBALL

FFMPEG_CONFIGURE_FLAGS+=(--prefix=$BASE_DIR/$OUTPUT_DIR)

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat ffbuild/config.log && exit 1)

make
make install

sudo mv ${LD_DIR}/libmp3lame.so.bak ${LD_DIR}/libmp3lame.so
sudo mv ${LD_DIR}/libmp3lame.so.0.bak ${LD_DIR}/libmp3lame.so.0
sudo mv ${LD_DIR}/libmp3lame.so.0.0.0.bak ${LD_DIR}/libmp3lame.so.0.0.0

chown $(stat -c '%u:%g' $BASE_DIR) -R $BASE_DIR/$OUTPUT_DIR
