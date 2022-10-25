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
#if !defined(__cplusplus) && !defined(true)
#define true 1
#define false 0
#endif

typedef i64 optional_u32;
#define nullopt -1

#define s_to_ms(s) ((s) * 1000ULL)
#define s_to_us(s) (s_to_ms(s) * 1000ULL)
#define s_to_ns(s) (s_to_us(s) * 1000ULL)

#define ms_to_s(ms) ((ms) / 1000.0)
#define us_to_s(us) ((us) / 1000.0 / 1000.0)
#define ns_to_s(ns) ((ns) / 1000.0 / 1000.0 / 1000.0)

#define PI 3.14159265358979323846f
#define RAD(D) (D*(PI/180.0f))
#define DEG(R) (R*(180.0f/PI))

#define MIN(A, B) ((A) < (B) ? (A) : (B))
#define MAX(A, B) ((A) > (B) ? (A) : (B))
#define CLAMP(V, LOW, HIGH) MIN(MAX(V, LOW), HIGH)

#define LENGTH(ARRAY) (sizeof(ARRAY)/sizeof((ARRAY)[0]))

#define AKAssert(check) if (!(check)) {return result;}
