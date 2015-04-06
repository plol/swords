import std.stdio;
import std.string;
import std.exception;
import std.conv;

import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;

import imageformats;

string vertex_source = q{

    #version 330 core

    in vec3 pos;
    in vec2 UV_in;

    uniform mat4 mvp;

    out vec3 wat;
    out vec2 UV;

    void main() {
        vec4 v = vec4(pos, 1);
        gl_Position = mvp * v;
        wat = (pos + vec3(1,1,1)) / 2;
        UV = UV_in;
    }
};


string fragment_source = q{

    #version 330 core

    out vec3 color;
    in vec3 wat;
    in vec2 UV;

    uniform sampler2D myTextureSampler;

    void main() {
        color = texture2D(myTextureSampler, vec2(wat.x, -wat.y)).rgb;
    }
};

__gshared float max_anisotropic;

GLFWwindow* awkward_init() {

    if (!glfwInit()) {
        assert (0);
    }

    DerelictGL3.load();


    glfwWindowHint(GLFW_SAMPLES, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_RESIZABLE, false);

    auto window = glfwCreateWindow(1024, 768, "Heh!", null, null);

    if (window is null) {
        assert (0);
    }
    glfwMakeContextCurrent(window);
    glfwSetInputMode(window, GLFW_STICKY_KEYS, true);

    DerelictGL3.reload();

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &max_anisotropic);

    // sorcery:
    uint vertex_array_id;
    glGenVertexArrays(1, &vertex_array_id);
    glBindVertexArray(vertex_array_id);
    // sorcery over

    return window;
}

void check_stuff(alias get, alias get_info_log, uint status_param)(uint id) {
    int successful = 0;
    get(id, status_param, &successful);
    if (!successful) {
        int info_length;
        get(id, GL_INFO_LOG_LENGTH, &info_length);
        auto message = new char[](info_length);
        get_info_log(id, info_length, null, &message[0]);
        throw new Exception(
                text("result = ", successful,
                    ", message = (", info_length, ")\"", message[0..$-2], "\""));
    }
}

alias validate_shader = check_stuff!(
        glGetShaderiv, glGetShaderInfoLog, GL_COMPILE_STATUS);
alias validate_program = check_stuff!(
        glGetProgramiv, glGetProgramInfoLog, GL_LINK_STATUS);

uint create_shader(uint shader_type, string source) {
    uint shader_id = glCreateShader(shader_type);
    auto source_pointer = source.toStringz();
    glShaderSource(shader_id, 1, &source_pointer, null);
    glCompileShader(shader_id);
    validate_shader(shader_id);
    return shader_id;
}

uint load_shaders(string vertex_code, string fragment_code) {
    uint vertex_shader_id = create_shader(GL_VERTEX_SHADER, vertex_code);
    uint fragment_shader_id = create_shader(GL_FRAGMENT_SHADER, fragment_code);
    uint program_id = glCreateProgram();
    glAttachShader(program_id, vertex_shader_id);
    glAttachShader(program_id, fragment_shader_id);
    glLinkProgram(program_id);
    validate_program(program_id);
    glDeleteShader(vertex_shader_id);
    glDeleteShader(fragment_shader_id);
    return program_id;
}

void check_error(int line=__LINE__)() {
    auto error = glGetError();
    enforce(error == GL_NO_ERROR, "error before line %s: 0x%x".format(line,  error));
}


uint load_texture_from_file(string filename) {

    auto im = read_image(filename);

    uint texture_id;
    glGenTextures(1, &texture_id);

    glBindTexture(GL_TEXTURE_2D, texture_id);

    glTexImage2D(GL_TEXTURE_2D, 0, cast(int)GL_RGB8, to!int(im.w), to!int(im.h),
            0, GL_RGB, GL_UNSIGNED_BYTE, im.pixels.ptr);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
            GL_LINEAR_MIPMAP_LINEAR);
    glGenerateMipmap(GL_TEXTURE_2D);

    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, max_anisotropic);

    return texture_id;
}

void bind_texture_to_port_thing(uint texture_id, uint port) {
    glActiveTexture(GL_TEXTURE0 + port);
    glBindTexture(GL_TEXTURE_2D, texture_id);
}

struct Buffer(T) {
    uint id;
    int num_objects;

    void upload(const T[] data) {
        num_objects = to!int(data.length);

        glBindBuffer(GL_ARRAY_BUFFER, id);
        glBufferData(GL_ARRAY_BUFFER, T.sizeof * data.length, data.ptr,
                GL_STATIC_DRAW);
    }
    void bind_to_vertex_attrib(int vertex_attrib) {
        glBindBuffer(GL_ARRAY_BUFFER, id);
        glVertexAttribPointer(vertex_attrib, T.sizeof / float.sizeof, GL_FLOAT,
                GL_FALSE, 0, null); }
}

Buffer!T create_buffer(T)() {
    uint id;
    glGenBuffers(1, &id);
    return Buffer!T(id);
}

struct Uniform(T) {
    uint id;
    void upload(T val) {
        static if (is(T == mat4)) {
            glUniformMatrix4fv(id, 1, true, val.value_ptr);
        } else static if (is(T == int)) {
            glUniform1i(id, val);
        }
    }
}


Uniform!T create_uniform(T)(uint program_id, string name) {
    return Uniform!T(glGetUniformLocation(program_id, name.toStringz));
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

        auto model = mat4.identity;
        auto mvp = vp * model;

        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);

        glUseProgram(program_id);

        vertex_buffer.bind_to_vertex_attrib(0);
        uv_buffer.bind_to_vertex_attrib(1);

        mvp_uniform.upload(mvp);

        bind_texture_to_port_thing(texture_id, 0);
        sampler_uniform.upload(0);

        glDrawArrays(GL_TRIANGLES, 0, vertex_buffer.num_objects);

        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
}

