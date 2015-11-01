import std.string;
import std.exception;
import std.conv;
import std.range;
import core.thread;
import core.time;

import std.experimental.logger;

import gl3n.linalg;

import engine;
import networking;
import protocol = networking.protocol;
import thread_management;
import server;

import async_stuff;


void move_towards(ref vec3 move_this, vec3 towards_this, double with_this_speed) {
    auto delta = towards_this - move_this;
    if (delta.length <= with_this_speed) {
        move_this = towards_this;
    } else {
        move_this += with_this_speed * delta.normalized;
    }
}
void move_towards_adaptive(ref vec3 move_this, vec3 towards_this,
        double with_this_speed, double adaptive_factor) {
    auto delta = towards_this - move_this;
    auto adaptive_speed = with_this_speed + adaptive_factor * delta.length;
    move_towards(move_this, towards_this, adaptive_speed);
}

struct ControllerState {
    Camera camera;
}

struct Camera {
    vec3 pos;
    auto angle = quat.zrotation(0);
    auto speed = 10;

    auto look_at_delta() {
        return angle * vec3(0,7,9);
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
    void gradual_center_on(vec3 target, double dt) {
        pos.move_towards_adaptive(target + look_at_delta(), speed * dt, 2*dt);
    }
}

struct Unit {
    vec3 pos = vec3(0, 0, 0);
    vec3 desired_pos = vec3(0, 0, 0);

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
        desired_pos += distance * right();
    }

    void move_left(float distance) {
        desired_pos -= distance * right();
    }

    void move_forward(float distance) {
        desired_pos += distance * forward();
    }

    void move_backward(float distance) {
        desired_pos -= distance * forward();
    }

    void move_towards_desired_pos(double dt) {
        pos.move_towards(desired_pos, speed*dt);
    }
}

Unit create_unit(Model model) {
    uint texture_id = load_texture_from_file("box-01.jpg");

    auto pos = vec3(0, 0, 0);

    return Unit(pos, pos, 6, quat.identity, model);
}


void main() {
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

    struct Box {
        Model model;
        int time_left;
    }

    Box[] boxes;

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


    ctrl.camera.center_on(unit.pos);

    auto server = spawn_thread!(Server, () => new Server)();

    Thread.sleep(1.seconds);

    scope (exit) {
        server.kill();
    }

    auto client_connection = connect_to_server("localhost", 12345);

    bool send_frame_ok_pls;

    void send_commands_to_server() {

        protocol.UnitMoveCommand move;

        if (window.is_key_pressed("R")) {
        }
        if (window.is_key_pressed("T")) {
        }
        if (window.is_key_pressed("Q")) {
            move.turn = protocol.UnitMoveCommand.LeftRightMotion.LEFT;
        }
        if (window.is_key_pressed("E")) {
            move.turn = protocol.UnitMoveCommand.LeftRightMotion.RIGHT;
        }

        if (window.is_key_pressed("W")) {
            move.forward = protocol.UnitMoveCommand.ForwardMotion.FORWARD;
        }
        if (window.is_key_pressed("S")) {
            move.forward = protocol.UnitMoveCommand.ForwardMotion.BACKWARD;
        }
        if (window.is_key_pressed("A")) {
            move.strafe = protocol.UnitMoveCommand.LeftRightMotion.LEFT;
        }
        if (window.is_key_pressed("D")) {
            move.strafe = protocol.UnitMoveCommand.LeftRightMotion.RIGHT;
        }
        protocol.UnitCommand command;

        command.unit_id = 1;//HACK

        if (move.turn.exists() || move.forward.exists() || move.strafe.exists()) {
            command.move = move;
        }

        protocol.UplinkCommands cmds;
        cmds.unit_actions ~= command;

        if (send_frame_ok_pls) {
            cmds.frame_ok = protocol.Frame();
            send_frame_ok_pls = false;
        }
        client_connection.write_commands(cmds);
    }
    client_connection.on_command = (cmds) {
        if (cmds.frame_update.exists()) {
            send_frame_ok_pls = true;

            Box[] new_boxes;
            foreach (box; boxes) {
                box.time_left -= 1;
                if (box.time_left > 0) {
                    new_boxes ~= box;
                }
            }
            boxes = new_boxes;
        }
        foreach (action; cmds.unit_actions) {
            auto target = vec3(0, 0, 0);
            target.x = action.to.x;
            target.z = action.to.y;

            unit.desired_pos = target;
        }

        foreach (box; cmds.debug_boxes) {
            float x = box.low.x + 0.1;
            float y = box.low.y + 0.1;
            float scaling_x = box.high.x - box.low.x + 0.8;
            float scaling_y = box.high.y - box.low.y + 0.8;
            boxes ~= Box(
                    Model(vertex_buffer, uv_buffer,
                        vec3(x, 0.8 + box.altitude, y), quat.identity,
                        vec3(scaling_x, 0.8, scaling_y)),
                    box.duration_in_ticks);
        }
    };

    auto projection = mat4.perspective(1024, 768, 90, 0.1, 1000);
    
    call_every(16.msecs, () => stop_event_loop());
    call_every(32.msecs, () => send_commands_to_server());


    struct FrameTimeCounterThing {
        MonoTime last_frame_time;
        MonoTime fps_timer;
        int frames_this_second;
        int fps;

        void init() {

            last_frame_time = MonoTime.currTime;
            fps_timer = MonoTime.currTime;
        }

        double frame() {
            auto now = MonoTime.currTime;
            auto delta_time = now - last_frame_time;
            last_frame_time = now;

            update_fps(now);

            return delta_time.total!"hnsecs" / 10_000_000.0;
        }

        void update_fps(MonoTime now) {
            frames_this_second += 1;
            if (now - fps_timer >= 1.seconds) {
                fps = frames_this_second;
                frames_this_second = 0;
                fps_timer = now;
            }
        }
    }

    FrameTimeCounterThing timekeeper;

    timekeeper.init();

    while (window.should_continue()) {
        run_event_loop_forever(); // This gets stopped by the call_every a
                                  // coupleof lines above

        auto dt = timekeeper.frame();


        unit.move_towards_desired_pos(dt);
        ctrl.camera.gradual_center_on(unit.pos, dt);

        auto view = mat4.look_at(ctrl.camera.pos, unit.pos, y);

        auto vp = projection * view;

        foreach (model; models) {
            r.render(vp, model, 0, texture_id);
        }


        foreach (box; boxes) {
            r.render(vp, box.model, 0, texture_id);
        }



        unit.model.pos = unit.pos;

        r.render(vp, unit.model, 0, texture_id);

        window.swap_buffers();
    }
}

