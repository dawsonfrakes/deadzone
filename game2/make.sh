#!/usr/bin/env bash

# example: ./make.sh shaders && ./make.sh build linux && ./make.sh run

set -e

CC="${CC:-"zig cc"}"

mkdir -p out
case "$1" in
    build)
        case "$2" in
            linux) $CC -Wall -Wextra -pedantic src/emain.c -lm -lX11 -lvulkan -o out/game ;;
            windows) $CC -Wall -Wextra -pedantic -target x86_64-windows src/emain.c -lm -lvulkan-1 -o out/game.exe ;;
            *) echo "usage: $0 build <linux|windows>"; exit 1 ;;
        esac
    ;;
    shaders) spirv-link <(glslc shaders/mesh.vert -o -) <(glslc shaders/mesh.frag -o -) -o - | xxd -i -n meshspv > out/mesh.spv.h ;;
    run) ./out/game ;;
    clean) rm -r out ;;
    *) echo "usage: $0 <build <linux|windows>|shaders|run|clean>"; exit 1 ;;
esac
