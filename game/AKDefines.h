#pragma once

#include <stdint.h>

typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef intptr_t isize;

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef uintptr_t usize;

typedef uint32_t bool32;
#define true 1
#define false 0

#define nullopt -1
typedef i64 optional_u32;

#define MIN(A, B) ((A) < (B) ? (A) : (B))
#define MAX(A, B) ((A) > (B) ? (A) : (B))
#define CLAMP(V, LOW, HIGH) MIN(MAX(V, LOW), HIGH)
#define LENGTH(ARRAY) (sizeof(ARRAY)/sizeof((ARRAY)[0]))
#define AKAssert(check) if (!(check)) {return result;}
