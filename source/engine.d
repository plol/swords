import std.stdio;
import std.string;
import std.exception;
import std.conv;
import std.utf;
import std.range;

import std.experimental.logger;

import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;
import imageformats;

import backtrace;

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
        //color = texture2D(myTextureSampler, vec2(wat.x, -wat.y)).rgb;
        color = texture2D(myTextureSampler, UV).rgb;
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

    backtrace.install(stdout);

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
        log(data);
        num_objects = to!int(data.length);

        glBindBuffer(GL_ARRAY_BUFFER, id);
        check_error();
        glBufferData(GL_ARRAY_BUFFER, T.sizeof * data.length, data.ptr,
                GL_STATIC_DRAW);
        check_error();
    }
    void bind_to_vertex_attrib(int vertex_attrib) {
        glBindBuffer(GL_ARRAY_BUFFER, id);
        glVertexAttribPointer(vertex_attrib, T.sizeof / float.sizeof, GL_FLOAT,
                GL_FALSE, 0, null);
        check_error();
    }
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


bool should_continue(GLFWwindow* window) {
    return !glfwWindowShouldClose(window);
}

void swap_buffers(GLFWwindow* window) {
    check_error();
    glfwSwapBuffers(window);
    glfwPollEvents();
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    check_error();
}


bool is_key_pressed(GLFWwindow* window, string key) {
    if (key.length == 1) {
        return glfwGetKey(window, key[0]) == GLFW_PRESS;
    }
    assert (0);
}






