// 2>/dev/null; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT; cc $0 -o "$tmp" && "$tmp" $@; exit
// example: sh build.c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>

#include "src/platform.h"

typedef struct ComptimeV2 { float x, y; } ComptimeV2;
typedef struct ComptimeV3 { float x, y, z; } ComptimeV3;

typedef struct ComptimeVertex {
    ComptimeV3 position;
    ComptimeV3 normal;
    ComptimeV2 texcoord;
} ComptimeVertex;

typedef struct ComptimeFace {
    size_t position_indices[3];
    size_t normal_indices[3];
    size_t texcoord_indices[3];
} ComptimeFace;

static ComptimeVertex *parse_obj(const char *const filepath, size_t *len)
{
    FILE *f = fopen(filepath, "r");

    ComptimeV3 positions[4096];
    size_t num_positions = 0;

    ComptimeV3 normals[4096];
    size_t num_normals = 0;

    // ComptimeV2 texcoords[4096];
    // size_t num_texcoords = 0;

    ComptimeFace faces[4096];
    size_t num_faces = 0;

    char line[2048];
    while (fgets(line, sizeof(line), f)) {
        char *token = strtok(line, " ");
        if (strcmp(token, "v") == 0) {
            const char *right = line + strlen(token) + 1;
            sscanf(right, "%f %f %f", &positions[num_positions].x, &positions[num_positions].y, &positions[num_positions].z);
            num_positions += 1;
        } else if (strcmp(token, "vn") == 0) {
            const char *right = line + strlen(token) + 1;
            sscanf(right, "%f %f %f", &normals[num_normals].x, &normals[num_normals].y, &normals[num_normals].z);
            num_normals += 1;
        } else if (strcmp(token, "f") == 0) {
            const char *right = line + strlen(token) + 1;
            sscanf(right, "%d/%*d/%d %d/%*d/%d %d/%*d/%d",
                faces[num_faces].position_indices+0, faces[num_faces].normal_indices+0,
                faces[num_faces].position_indices+1, faces[num_faces].normal_indices+1,
                faces[num_faces].position_indices+2, faces[num_faces].normal_indices+2
            );
            num_faces += 1;
        }
    }

    fclose(f);

    ComptimeVertex *result = calloc(3 * num_faces, sizeof(ComptimeVertex));
    if (len) *len = num_faces * 3;
    for (size_t i = 0; i < num_faces; ++i) {
        result[i * 3 + 0].position = positions[faces[i].position_indices[0] - 1];
        result[i * 3 + 0].normal = normals[faces[i].normal_indices[0] - 1];
        result[i * 3 + 1].position = positions[faces[i].position_indices[1] - 1];
        result[i * 3 + 1].normal = normals[faces[i].normal_indices[1] - 1];
        result[i * 3 + 2].position = positions[faces[i].position_indices[2] - 1];
        result[i * 3 + 2].normal = normals[faces[i].normal_indices[2] - 1];
    }

    return result;
}

static const char *getenvorelse(const char *const name, const char *const orelse)
{
    const char *var = getenv(name);
    return var ? var : orelse;
}

static void cmd(char **const result, const char *const fmt, ...)
{
    static char s[2048];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(s, sizeof(s), fmt, ap);
    va_end(ap);
    printf("build.c: %s\n", s);
    if (result) {
        FILE *f = popen(s, "r");
        *result = malloc(16384UL);
        (*result)[0] = 0;
        char line[1024];
        while (fgets(line, sizeof(line), f)) {
            strcat(*result, line);
        }
        pclose(f);
    } else {
        if (system(s) != 0)
            exit(EXIT_FAILURE);
    }
}

int main(void)
{
    const char *const cc        = getenvorelse("CC", "zig cc");
    const char *const cflags    = getenvorelse("CFLAGS", "-std=c99 -Wall -Wextra -pedantic -g");
    const char *const ldflags   = getenvorelse("LDFLAGS", "-Wl,-E -lm -lvulkan -lX11 -ldl");
    const char *const outdir    = getenvorelse("OUTDIR", "./out");
    const char *const target    = getenvorelse("TARGET", "game");
    const char *const src       = getenvorelse("SRC", "src/emain.c");
    const char *spvln           = getenvorelse("SPVLN", "spirv-link");
    const char *spvcc           = getenvorelse("SPVCC", "glslc");

    cmd(NULL, "mkdir -p \"%s\"", outdir);

    // comptime generation
    {
        char comptimepath[2048] = {0};
        snprintf(comptimepath, sizeof(comptimepath), "%s/comptime.h", outdir);
        FILE *comptime = fopen(comptimepath, "w");

        char *spvout;
        cmd(&spvout, "%s <(%s shaders/mesh.vert -o -) <(%s shaders/mesh.frag -o -) -o - | xxd -i", spvln, spvcc, spvcc, outdir);
        fprintf(comptime, "static const u8 meshspv[] = {\n%s};\n", spvout);
        free(spvout);

        char *meshes;
        cmd(&meshes, "basename -s .obj -a meshes/*.obj");
        fprintf(comptime, "enum Mesh {\n");

        for (char *token = meshes; *token; ++token) {
            fprintf(comptime, "\tMESH_");
            while (*token && *token != '\n')
                fprintf(comptime, "%c", toupper(*token++));
            fprintf(comptime, ",\n");
        }
        fprintf(comptime, "\tMESH_LENGTH,\n};\n");

        fprintf(comptime,
            "typedef struct Vertex {\n"
            "    V3 position;\n"
            "    V3 normal;\n"
            "    V2 texcoord;\n"
            "} Vertex;\n"
            "typedef struct VertexSlice {\n"
            "   const Vertex *vertices;\n"
            "   usize len;\n"
            "} VertexSlice;\n"
#if RENDERING_API == RAPI_VULKAN
            "typedef struct MeshPushConstants {\n"
            "    M4 mvp;\n"
            "} MeshPushConstants;\n"
            "static const VkVertexInputBindingDescription vertex_bindings[] = {\n"
            "    {\n"
            "        .binding = 0,\n"
            "        .inputRate = VK_VERTEX_INPUT_RATE_VERTEX,\n"
            "        .stride = sizeof(Vertex),\n"
            "    }\n"
            "};\n"

            "static const VkVertexInputAttributeDescription vertex_attributes[] = {\n"
            "    {\n"
            "        .binding = 0,\n"
            "        .location = 0,\n"
            "        .format = VK_FORMAT_R32G32B32_SFLOAT,\n"
            "        .offset = offsetof(Vertex, position),\n"
            "    },\n"
            "    {\n"
            "        .binding = 0,\n"
            "        .location = 1,\n"
            "        .format = VK_FORMAT_R32G32B32_SFLOAT,\n"
            "        .offset = offsetof(Vertex, normal),\n"
            "    },\n"
            "    {\n"
            "        .binding = 0,\n"
            "        .location = 2,\n"
            "        .format = VK_FORMAT_R32G32_SFLOAT,\n"
            "        .offset = offsetof(Vertex, texcoord),\n"
            "    },\n"
            "};\n"
#endif
        );

        for (char *token = meshes; *token; ++token) {
            char name[1024] = {0};
            size_t cursor = 0;
            while (*token && *token != '\n')
                name[cursor++] = *token++;

            char path[1024];
            snprintf(path, sizeof(path), "meshes/%s.obj", name);

            size_t num_vertices;
            ComptimeVertex *vertices = parse_obj(path, &num_vertices);
            fprintf(comptime, "static const Vertex %smesh[] = {\n", name);
            for (size_t i = 0; i < num_vertices; ++i) {
                fprintf(comptime,
                    "\t{\n\t\t.position = { .x = %f, .y = %f, .z = %f },\n\t\t.normal = { .x = %f, .y = %f, .z = %f }\n\t},\n",
                    vertices[i].position.x, vertices[i].position.y, vertices[i].position.z,
                    vertices[i].normal.x, vertices[i].normal.y, vertices[i].normal.z
                );
            }
            fputs("};\n", comptime);
            free(vertices);

        }

        fputs("static const VertexSlice meshes[MESH_LENGTH] = {\n", comptime);
        for (char *token = meshes; *token; ++token) {
            char name[1024] = {0};
            size_t cursor = 0;
            while (*token && *token != '\n')
                name[cursor++] = *token++;

            fprintf(comptime, "\t{\n\t\t.vertices = %smesh,\n\t\t.len = len(%smesh)\n\t},\n", name, name);
        }
        fputs("};\n", comptime);

        free(meshes);
        fclose(comptime);
    }

    // build
    cmd(NULL, "%s %s %s %s -o %s/%s", cc, cflags, src, ldflags, outdir, target);

    // run
    cmd(NULL, "%s/%s", outdir, target);

    // clean
    // cmd(NULL, "rm -rI %s", outdir);
}
