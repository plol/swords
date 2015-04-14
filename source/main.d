import std.string;
import std.exception;
import std.conv;
import std.range;

import std.experimental.logger;

import gl3n.linalg;

import graphics;
static import engine;

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
    log(x);
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
void main()
{
    scope (exit) {
        log("exiting");
    }

    auto window = engine.awkward_init();

    vec3 origo = vec3(0,0,0);
    vec3 x = vec3(1,0,0);
    vec3 y = vec3(0,1,0);
    vec3 z = vec3(0,0,1);

    vec3[] vertex_buffer_data;
    foreach (v; [x,y,z,-x,-y,-z]) {
        vertex_buffer_data ~= square_face(1, v, v);
    }

    auto vertex_buffer = engine.create_buffer!vec3();
    auto uv_buffer = engine.create_buffer!vec2();

    vertex_buffer.upload(vertex_buffer_data);
    uv_buffer.upload(vertex_buffer_data.create_uv_data_for_cube());

    Model[] models;

    models ~= Model(vertex_buffer, uv_buffer, vec3(0,0,0), quat.identity, 10);
    models ~= Model(vertex_buffer, uv_buffer, vec3(30,0,0), quat.identity, 10);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,30,0), quat.identity, 10);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,0,30), quat.identity, 10);
    models ~= Model(vertex_buffer, uv_buffer, vec3(-30,0,0), quat.identity, 10);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,-30,0), quat.identity, 10);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,0,-30), quat.identity, 10);

    auto vertex_buffer_floor_data = square_face(100, y, origo);

    auto vertex_buffer_floor = engine.create_buffer!vec3();
    auto uv_buffer_floor = engine.create_buffer!vec2();

    vertex_buffer_floor.upload(vertex_buffer_floor_data[]);
    uv_buffer_floor.upload(square_face(1, x, origo).create_uv_data_for_cube());

    models ~= Model(vertex_buffer_floor, uv_buffer_floor, origo, quat.identity, 1);

    Renderer r;
    r.init();

    uint texture_id = engine.load_texture_from_file("box-01.jpg");

    auto unit_pos = vec2(0, 0);
    auto camera_angle = quat.zrotation(0);

    auto camera_speed = 0.3;

    auto unit_model = Model(vertex_buffer, uv_buffer, origo, quat.identity, 1);
    
    while (engine.should_continue(window)) {

        if (engine.is_key_pressed(window, "R")) {
            unit_model.rotation.rotatey(0.05);
        }
        if (engine.is_key_pressed(window, "T")) {
            unit_model.rotation.rotatey(-0.05);
        }
        if (engine.is_key_pressed(window, "Q")) {
            camera_angle.rotatey(0.05);
            unit_model.rotation.rotatey(0.05);
        }
        if (engine.is_key_pressed(window, "E")) {
            camera_angle.rotatey(-0.05);
            unit_model.rotation.rotatey(-0.05);
        }

        auto look_at_delta = camera_angle * vec3(0,-0.2,-1);

        auto right = look_at_delta.cross(y);
        auto forward = y.cross(right);

        if (engine.is_key_pressed(window, "W")) {
            unit_pos += camera_speed * forward.xz;
        }
        if (engine.is_key_pressed(window, "A")) {
            unit_pos -= camera_speed * right.xz;
        }
        if (engine.is_key_pressed(window, "S")) {
            unit_pos -= camera_speed * forward.xz;
        }
        if (engine.is_key_pressed(window, "D")) {
            unit_pos += camera_speed * right.xz;
        }

        auto unit_pos_3d = vec3(unit_pos.x, 0, unit_pos.y);

        auto camera_pos = unit_pos_3d - 10*look_at_delta + 5*y;

        auto projection = mat4.perspective(1024, 768, 90, 0.1, 1000);
        auto view = mat4.look_at(camera_pos, unit_pos_3d, y);

        auto vp = projection * view;

        foreach (model; models) {
            r.render(vp, model, 0, texture_id);
        }
        unit_model.pos = unit_pos_3d;

        r.render(vp, unit_model, 0, texture_id);

        engine.swap_buffers(window);
    }
}

