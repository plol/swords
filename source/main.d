import std.string;
import std.exception;
import std.conv;
import std.range;

import std.experimental.logger;

import gl3n.linalg;

import engine;


struct ControllerState {
    Camera camera;
}

struct Camera {
    vec3 pos;
    auto angle = quat.zrotation(0);
    auto speed = 0.3;

    auto look_at_delta() {
        return angle * vec3(0,14,18);
    }
    void turn_left(float rads) {
        angle.rotatey(rads);
    }
    void turn_right(float rads) {
        angle.rotatey(-rads);
    }

    void center_on(vec3 target) {
        pos = target + look_at_delta();
    }
}

struct Unit {
    vec3 pos = vec3(0, 0, 0);

    float speed = 0;

    quat rotation = quat.identity;

    Model model;

    void turn_left(float rads) {
        rotation.rotatey(rads);
        model.turn_left(rads);
    }

    void turn_right(float rads) {
        rotation.rotatey(-rads);
        model.turn_right(rads);
    }

    vec3 forward() {
        return rotation * vec3(0,0,-1);
    }
    vec3 right() {
        return rotation * vec3(1, 0, 0);
    }

    void move_right(float distance) {
        pos += distance * right();
    }

    void move_left(float distance) {
        pos -= distance * right();
    }

    void move_forward(float distance) {
        pos += distance * forward();
    }

    void move_backward(float distance) {
        pos -= distance * forward();
    }
}

Unit create_unit(Model model) {
    uint texture_id = load_texture_from_file("box-01.jpg");

    auto pos = vec3(0, 0, 0);

    return Unit(pos, 0.3, quat.identity, model);
}


void main()
{
    scope (exit) {
        log("exiting");
    }

    auto window = create_window();

    vec3 origo = vec3(0,0,0);
    vec3 x = vec3(1,0,0);
    vec3 y = vec3(0,1,0);
    vec3 z = vec3(0,0,1);

    vec3[] vertex_buffer_data;
    foreach (v; [x,y,z,-x,-y,-z]) {
        vertex_buffer_data ~= square_face(1, v, v);
    }
    uint texture_id = load_texture_from_file("box-01.jpg");

    auto vertex_buffer = create_buffer!vec3();
    auto uv_buffer = create_buffer!vec2();

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

    auto vertex_buffer_floor = create_buffer!vec3();
    auto uv_buffer_floor = create_buffer!vec2();

    vertex_buffer_floor.upload(vertex_buffer_floor_data[]);
    uv_buffer_floor.upload(square_face(1, x, origo).create_uv_data_for_cube());

    models ~= Model(vertex_buffer_floor, uv_buffer_floor, origo, quat.identity, 1);

    Renderer r;
    r.init();

    ControllerState ctrl;
    Unit unit = create_unit(Model(vertex_buffer, uv_buffer, origo,
                quat.identity, 1));


    auto unit_pos = vec2(0, 0);
    auto camera_angle = quat.zrotation(0);

    auto camera_speed = 0.3;

    auto projection = mat4.perspective(1024, 768, 90, 0.1, 1000);
    
    while (window.should_continue()) {

        if (window.is_key_pressed("R")) {
            unit.turn_left(0.05);
        }
        if (window.is_key_pressed("T")) {
            unit.turn_right(0.05);
        }
        if (window.is_key_pressed("Q")) {
            ctrl.camera.turn_left(0.05);
            unit.turn_left(0.05);
        }
        if (window.is_key_pressed("E")) {
            ctrl.camera.turn_right(0.05);
            unit.turn_right(0.05);
        }

        if (window.is_key_pressed("W")) {
            unit.move_forward(unit.speed);
        }
        if (window.is_key_pressed("S")) {
            unit.move_backward(unit.speed);
        }
        if (window.is_key_pressed("A")) {
            unit.move_left(unit.speed);
        }
        if (window.is_key_pressed("D")) {
            unit.move_right(unit.speed);
        }

        ctrl.camera.center_on(unit.pos);

        auto view = mat4.look_at(ctrl.camera.pos, unit.pos, y);

        auto vp = projection * view;

        foreach (model; models) {
            r.render(vp, model, 0, texture_id);
        }
        unit.model.pos = unit.pos;

        r.render(vp, unit.model, 0, texture_id);

        window.swap_buffers();
    }
}

