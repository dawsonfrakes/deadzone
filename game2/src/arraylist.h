#pragma once

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct ArrayList {
    size_t size;
    size_t length;
    size_t capacity;
    void *data;
} ArrayList;

#define ArrayList_init(type) { .size = sizeof(type), .length = 0, .capacity = 0, .data = NULL }
#define ArrayList_resize(list, length) do { list.capacity = (length); list.data = realloc(list.data, list.size * list.capacity); } while (0)
#define ArrayList_has_space(list) (list.capacity - list.length > 0)
#define ArrayList_get(list, index) ((uint8_t *)(list.data)+(list.size * index))
#define ArrayList_append(list, element_ptr) do { if (!ArrayList_has_space(list)) ArrayList_resize(list, list.capacity + 3); memcpy(ArrayList_get(list, list.length), element_ptr, list.size); ++list.length; } while (0)
#define ArrayList_delete(list, index) do { memmove(ArrayList_get(list, index + 1), ArrayList_get(list, index), list.size * (list.length - 1 - index)); --list.length; } while (0)
#define ArrayList_deinit(list) do { free(list.data); } while (0)
