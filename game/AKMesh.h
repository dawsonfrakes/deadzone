#pragma once

typedef struct Vertex {
    V3 position;
    V3 normal;
    V3 color;
} Vertex;

typedef struct Mesh {
    ArrayList/*<Vertex>*/ vertices;
    struct APISpecificMeshData data;
} Mesh;
