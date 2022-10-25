#!/bin/sh

set -e

SOURCE="game.c AKUtils.c"
TARGET="game"
OUTDIR="./bin/"
CC="gcc"
CFLAGS="-std=c99 -Wall -Wextra -pedantic -Og -ggdb"
DEFINES="-D_POSIX_C_SOURCE=200809L"
LDFLAGS="-lm"

# linux
SOURCE="$SOURCE AKXlibWindow.c"
DEFINES="$DEFINES -DAK_USE_XLIB"
LDFLAGS="$LDFLAGS -lX11"

# windows (coming soon)
# SOURCE="$SOURCE AKWin32Window.c"
# DEFINES="$DEFINES -DAK_USE_WIN32"

# vulkan
SOURCE="$SOURCE AKVkRenderer.c"
DEFINES="$DEFINES -DAK_USE_VULKAN"
LDFLAGS="$LDFLAGS -lvulkan"

mkdir -p "$OUTDIR"

SHADERDIR="./shaders/"
SHADERS="colored_triangle.vert colored_triangle.frag red_triangle.vert red_triangle.frag"
for FILE in $SHADERS; do
    glslc "$SHADERDIR$FILE" -o "$OUTDIR$FILE.spv"
done

$CC -o "$OUTDIR$TARGET" $CFLAGS $DEFINES $SOURCE $LDFLAGS

case "$1" in
    run) exec "$OUTDIR/$TARGET" ;;
    clean) rm -v "$OUTDIR"{"$TARGET",*.spv} ;;
    *) ;;
esac
