// 2>/dev/null; tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT; cc $0 -o "$tmp" && "$tmp" $@; exit
// example: sh build.c

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

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

static ComptimeVertex *parse_obj(const char *filepath, size_t *len)
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
        system(s);
    }
}

int main(void)
{
    const char *const cc        = getenvorelse("CC", "cc");
    const char *const cflags    = getenvorelse("CFLAGS", "-std=c99 -Wall -Wextra -pedantic");
    const char *const ldflags   = getenvorelse("LDFLAGS", "-lm -lvulkan -lX11");
    const char *const outdir    = getenvorelse("OUTDIR", "./out");
    const char *const target    = getenvorelse("TARGET", "game");
    const char *const src       = getenvorelse("SRC", "src/emain.c");

    // comptime generation
    {
        const char *spvlinker = "spirv-link";
        const char *spvcomp = "glslc";
        char comptimepath[2048] = {0};
        snprintf(comptimepath, sizeof(comptimepath), "%s/comptime.h", outdir);
        FILE *comptime = fopen(comptimepath, "w");
        char *spvout;
        cmd(&spvout, "%s <(%s shaders/mesh.vert -o -) <(%s shaders/mesh.frag -o -) -o - | xxd -i", spvlinker, spvcomp, spvcomp, outdir);
        size_t num_cube_vertices;
        ComptimeVertex *cube_vertices = parse_obj("meshes/cube.obj", &num_cube_vertices);
        size_t num_triangle_vertices;
        ComptimeVertex *triangle_vertices = parse_obj("meshes/triangle.obj", &num_triangle_vertices);

        fputs("static const u8 meshspv[] = {\n", comptime);
        fprintf(comptime, "%s};\n", spvout);

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
            "enum Mesh {\n"
            "    MESH_CUBE,\n"
            "    MESH_TRIANGLE,\n"
            "    MESH_LENGTH,\n"
            "};\n"
        );

        fputs("static const Vertex cubemesh[] = {\n", comptime);
        for (size_t i = 0; i < num_cube_vertices; ++i) {
            fprintf(comptime,
                "\t{\n\t\t.position = { .x = %f, .y = %f, .z = %f },\n\t\t.normal = { .x = %f, .y = %f, .z = %f }\n\t},\n",
                cube_vertices[i].position.x, cube_vertices[i].position.y, cube_vertices[i].position.z,
                cube_vertices[i].normal.x, cube_vertices[i].normal.y, cube_vertices[i].normal.z
            );
        }
        fputs("};\n", comptime);

        fputs("static const Vertex trianglemesh[] = {\n", comptime);
        for (size_t i = 0; i < num_triangle_vertices; ++i) {
            fprintf(comptime,
                "\t{\n\t\t.position = { .x = %f, .y = %f, .z = %f },\n\t\t.normal = { .x = %f, .y = %f, .z = %f }\n\t},\n",
                triangle_vertices[i].position.x, triangle_vertices[i].position.y, triangle_vertices[i].position.z,
                triangle_vertices[i].normal.x, triangle_vertices[i].normal.y, triangle_vertices[i].normal.z
            );
        }
        fputs("};\n", comptime);

        fputs("static const VertexSlice meshes[MESH_LENGTH] = {\n", comptime);
        for (size_t i = 0; i < 1/*MESH_LENGTH*/; ++i) {
            fprintf(comptime,
                "\t{\n\t\t.vertices = cubemesh,\n\t\t.len = len(cubemesh)\n\t},\n"
            );
            fprintf(comptime,
                "\t{\n\t\t.vertices = trianglemesh,\n\t\t.len = len(trianglemesh)\n\t},\n"
            );
        }
        fputs("};\n", comptime);

        free(triangle_vertices);
        free(cube_vertices);
        free(spvout);
        fclose(comptime);
    }

    // build
    cmd(NULL, "%s %s %s %s -o %s/%s", cc, cflags, src, ldflags, outdir, target);

    // run
    cmd(NULL, "%s/%s", outdir, target);

    // clean
    // cmd(NULL, "rm -rI %s", outdir);
}
