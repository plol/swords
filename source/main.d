import std.stdio;
import std.string;
import std.exception;
import std.conv;

import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;

import engine;


struct Model {
    Buffer!vec3 vertex_buffer;
    Buffer!vec2 uv_buffer;

    vec3 pos;
    float rotation = 0;
    float scaling = 1;
}

void main()
{
    scope (exit) {
        writeln("exiting");
    }

    auto window = awkward_init();


    vec3[] vertex_buffer_data = [
        vec3(-1.0f, -1.0f, -1.0f), // triangle 1 : begin
        vec3(-1.0f, -1.0f, 1.0f),
        vec3(-1.0f, 1.0f, 1.0f), // triangle 1 : end
        vec3(1.0f, 1.0f, -1.0f), // triangle 2 : begin
        vec3(-1.0f, -1.0f, -1.0f),
        vec3(-1.0f, 1.0f, -1.0f), // triangle 2 : end
        vec3(1.0f, -1.0f, 1.0f),
        vec3(-1.0f, -1.0f, -1.0f),
        vec3(1.0f, -1.0f, -1.0f),
        vec3(1.0f, 1.0f, -1.0f),
        vec3(1.0f, -1.0f, -1.0f),
        vec3(-1.0f, -1.0f, -1.0f),
        vec3(-1.0f, -1.0f, -1.0f),
        vec3(-1.0f, 1.0f, 1.0f),
        vec3(-1.0f, 1.0f, -1.0f),
        vec3(1.0f, -1.0f, 1.0f),
        vec3(-1.0f, -1.0f, 1.0f),
        vec3(-1.0f, -1.0f, -1.0f),
        vec3(-1.0f, 1.0f, 1.0f),
        vec3(-1.0f, -1.0f, 1.0f),
        vec3(1.0f, -1.0f, 1.0f),
        vec3(1.0f, 1.0f, 1.0f),
        vec3(1.0f, -1.0f, -1.0f),
        vec3(1.0f, 1.0f, -1.0f),
        vec3(1.0f, -1.0f, -1.0f),
        vec3(1.0f, 1.0f, 1.0f),
        vec3(1.0f, -1.0f, 1.0f),
        vec3(1.0f, 1.0f, 1.0f),
        vec3(1.0f, 1.0f, -1.0f),
        vec3(-1.0f, 1.0f, -1.0f),
        vec3(1.0f, 1.0f, 1.0f),
        vec3(-1.0f, 1.0f, -1.0f),
        vec3(-1.0f, 1.0f, 1.0f),
        vec3(1.0f, 1.0f, 1.0f),
        vec3(-1.0f, 1.0f, 1.0f),
        vec3(1.0f, -1.0f, 1.0f)
            ];
    vec2[] g_uv_buffer_data = [
        vec2(0.000059f, 1.0f-0.000004f),
        vec2(0.000103f, 1.0f-0.336048f),
        vec2(0.335973f, 1.0f-0.335903f),
        vec2(1.000023f, 1.0f-0.000013f),
        vec2(0.667979f, 1.0f-0.335851f),
        vec2(0.999958f, 1.0f-0.336064f),
        vec2(0.667979f, 1.0f-0.335851f),
        vec2(0.336024f, 1.0f-0.671877f),
        vec2(0.667969f, 1.0f-0.671889f),
        vec2(1.000023f, 1.0f-0.000013f),
        vec2(0.668104f, 1.0f-0.000013f),
        vec2(0.667979f, 1.0f-0.335851f),
        vec2(0.000059f, 1.0f-0.000004f),
        vec2(0.335973f, 1.0f-0.335903f),
        vec2(0.336098f, 1.0f-0.000071f),
        vec2(0.667979f, 1.0f-0.335851f),
        vec2(0.335973f, 1.0f-0.335903f),
        vec2(0.336024f, 1.0f-0.671877f),
        vec2(1.000004f, 1.0f-0.671847f),
        vec2(0.999958f, 1.0f-0.336064f),
        vec2(0.667979f, 1.0f-0.335851f),
        vec2(0.668104f, 1.0f-0.000013f),
        vec2(0.335973f, 1.0f-0.335903f),
        vec2(0.667979f, 1.0f-0.335851f),
        vec2(0.335973f, 1.0f-0.335903f),
        vec2(0.668104f, 1.0f-0.000013f),
        vec2(0.336098f, 1.0f-0.000071f),
        vec2(0.000103f, 1.0f-0.336048f),
        vec2(0.000004f, 1.0f-0.671870f),
        vec2(0.336024f, 1.0f-0.671877f),
        vec2(0.000103f, 1.0f-0.336048f),
        vec2(0.336024f, 1.0f-0.671877f),
        vec2(0.335973f, 1.0f-0.335903f),
        vec2(0.667969f, 1.0f-0.671889f),
        vec2(1.000004f, 1.0f-0.671847f),
        vec2(0.667979f, 1.0f-0.335851f)
            ];

    auto vertex_buffer = create_buffer!vec3();
    auto uv_buffer = create_buffer!vec2();

    vertex_buffer.upload(vertex_buffer_data);
    uv_buffer.upload(g_uv_buffer_data);

    Model[] models;

    models ~= Model(vertex_buffer, uv_buffer, vec3(0,0,0), 0, 1);
    models ~= Model(vertex_buffer, uv_buffer, vec3(3,0,0), 1, 1);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,3,0), 2, 2);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,0,3), 3, 1);
    models ~= Model(vertex_buffer, uv_buffer, vec3(-3,0,0), 4, 1);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,-3,0), 5, 1);
    models ~= Model(vertex_buffer, uv_buffer, vec3(0,0,-3), 6, 1);


    auto program_id = load_shaders(vertex_source, fragment_source);

    auto mvp_uniform = create_uniform!mat4(program_id, "mvp");
    auto sampler_uniform = create_uniform!int(program_id, "myTextureSampler");

    uint texture_id = load_texture_from_file("box-01.jpg");
    
    uint n = 0;

    while (!glfwWindowShouldClose(window)) {
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        n += 1;

        auto projection = mat4.perspective(1024, 768, 90, 0.1, 100);
        auto view = mat4.look_at(vec3(3 - n*0.005, 2+0.0001, 2+n*0.001), vec3(0, 0, 0), vec3(0, 1, 0));

        auto vp = projection * view;

        foreach (model; models) {

            auto m = mat4.translation(model.pos.x, model.pos.y, model.pos.z)
                * mat4.zrotation(model.rotation + n * 0.1)
                * mat4.scaling(model.scaling, model.scaling, model.scaling);
            auto mvp = vp * m;

            glEnableVertexAttribArray(0);
            glEnableVertexAttribArray(1);

            glUseProgram(program_id);

            model.vertex_buffer.bind_to_vertex_attrib(0);
            model.uv_buffer.bind_to_vertex_attrib(1);

            mvp_uniform.upload(mvp);

            bind_texture_to_port_thing(texture_id, 0);
            sampler_uniform.upload(0);

            glDrawArrays(GL_TRIANGLES, 0, model.vertex_buffer.num_objects);

            glDisableVertexAttribArray(1);
            glDisableVertexAttribArray(0);
        }
        glfwSwapBuffers(window);
        glfwPollEvents();
    }
}

