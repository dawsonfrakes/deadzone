#pragma once

#include <stdint.h>

#define null ((void *)0)
#define true 1
#define false 0
#define assert(check) do { if (!(check)) { fprintf(stderr, #check "\n"); abort(); } } while (0)
#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))
#define len(array) (sizeof(array)/sizeof((array)[0]))

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef uintptr_t usize;

typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef intptr_t isize;

typedef uint32_t b32;

typedef float f32;
typedef double f64;
