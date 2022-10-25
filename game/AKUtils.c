#include "AKEngine.h"

#include <stdio.h>
#include <stdlib.h>

long read_file(const char *const filename, char **const output)
{
    FILE *f = fopen(filename, "r");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    rewind(f);
    *output = (char *) malloc(len + 1);
    if (!(*output)) {
        fclose(f);
        return -1;
    }
    len = fread(*output, 1, len, f);
    (*output)[len] = '\0';
    fclose(f);
    return len;
}

long read_binary_file(const char *const filename, char **const output)
{
    FILE *f = fopen(filename, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    rewind(f);
    *output = (char *) malloc(len);
    if (!(*output)) {
        fclose(f);
        return -1;
    }
    len = fread(*output, 1, len, f);
    fclose(f);
    return len;
}
