module engine.awkward_stuff;

import std.string;
import std.exception;
import std.conv;
import std.range;

import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;

import engine.graphics;

vec3 calculate_normal(vec3 a, vec3 b, vec3 c) {
    return cross(b-a, c-a).normalized();
}

float wonk(float x) {
    if (x < 0) {
        return 1;
    }
    if (x > 0) {
        return 0;
    }
    assert (0);
}


vec2[] create_uv_data_for_cube(vec3[] cube) {
    vec2[] ret;
    foreach (vertex; cube.chunks(3)) {
        auto v0 = vertex[0];
        auto v1 = vertex[1];
        auto v2 = vertex[2];
        auto n = calculate_normal(v0, v1, v2);

        foreach (v; vertex) {
            vec2 uv = vec2(0, 0);

            if (n.x != 0) {
                uv.x = wonk(v.z * -n.x);
                uv.y = wonk(v.y);
            }
            if (n.y != 0) {
                // 0 is good here
            }
            if (n.z != 0) {
                uv.x = wonk(v.x * n.z);
                uv.y = wonk(v.y);
            }

            ret ~= uv;
        }
    }
    return ret;
}


vec3 as_3d_with_normal(vec2 v, vec3 n) {
    if (n.x != 0) return vec3(0, v.y, v.x * n.x);
    if (n.y != 0) return vec3(v.x, 0, v.y);
    if (n.z != 0) return vec3(v.x * n.z, v.y, 0);
    assert (0);
}

vec3[6] square_face(float size, vec3 normal, vec3 centered_at) {
    auto n = normal.normalized();
    vec3[6] ret;

    vec2[6] points2d = [
        vec2(-1, -1), vec2(1, -1), vec2(1, 1),
        vec2(1, 1), vec2(-1, 1), vec2(-1, -1)
    ];

    foreach (i; 0 .. 6) {
        ret[i] = centered_at + size * points2d[i].as_3d_with_normal(n);
    }
    return ret;
}

