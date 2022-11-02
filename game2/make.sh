#!/usr/bin/env bash

# example: ./make.sh shaders && ./make.sh build linux && ./make.sh run

set -e

case "$1" in
    build)
        mkdir -p out
        case "$2" in
            linux) zig cc src/{engine_main.c,xlib_window.c,vulkan_renderer.c} -lX11 -lvulkan -o out/game ;;
            windows) zig cc -target x86_64-windows src/{engine_main.c,win32_window.c,vulkan_renderer.c} -lvulkan-1 -o out/game.exe ;;
            *) echo "usage: $0 build <linux|windows>"; exit 1 ;;
        esac
    ;;
    shaders) spirv-link <(glslc shaders/mesh.vert -o -) <(glslc shaders/mesh.frag -o -) -o - | xxd -i -n meshspv > out/mesh.spv.h ;;
    run) ./out/game ;;
    clean) rm -r out ;;
    *) echo "usage: $0 <build <linux|windows>|shaders|run|clean>"; exit 1 ;;
esac
