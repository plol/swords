import std.stdio;
import std.string;
import std.exception;
import std.conv;

import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;


string vertex_source = q{

    #version 330 core

    in vec3 pos;
    uniform mat4 mvp;


    void main() {
        vec4 v = vec4(pos, 1);
        gl_Position = mvp * v;
    }
};


string fragment_source = q{

    #version 330 core

    out vec3 color;

    void main() {
        color = vec3(0, 1, 1);
    }
};


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

void main()
{
    scope (exit) {
        writeln("exiting");
    }

    auto window = awkward_init();

    uint vertex_array_id;
    glGenVertexArrays(1, &vertex_array_id);
    glBindVertexArray(vertex_array_id);

    float[] vertex_buffer_data = [
    -1.0f, -1.0f, -1.0f, // triangle 1 : begin
    -1.0f, -1.0f, 1.0f,
    -1.0f, 1.0f, 1.0f, // triangle 1 : end
    1.0f, 1.0f, -1.0f, // triangle 2 : begin
    -1.0f, -1.0f, -1.0f,
    -1.0f, 1.0f, -1.0f, // triangle 2 : end
    1.0f, -1.0f, 1.0f,
    -1.0f, -1.0f, -1.0f,
    1.0f, -1.0f, -1.0f,
    1.0f, 1.0f, -1.0f,
    1.0f, -1.0f, -1.0f,
    -1.0f, -1.0f, -1.0f,
    -1.0f, -1.0f, -1.0f,
    -1.0f, 1.0f, 1.0f,
    -1.0f, 1.0f, -1.0f,
    1.0f, -1.0f, 1.0f,
    -1.0f, -1.0f, 1.0f,
    -1.0f, -1.0f, -1.0f,
    -1.0f, 1.0f, 1.0f,
    -1.0f, -1.0f, 1.0f,
    1.0f, -1.0f, 1.0f,
    1.0f, 1.0f, 1.0f,
    1.0f, -1.0f, -1.0f,
    1.0f, 1.0f, -1.0f,
    1.0f, -1.0f, -1.0f,
    1.0f, 1.0f, 1.0f,
    1.0f, -1.0f, 1.0f,
    1.0f, 1.0f, 1.0f,
    1.0f, 1.0f, -1.0f,
    -1.0f, 1.0f, -1.0f,
    1.0f, 1.0f, 1.0f,
    -1.0f, 1.0f, -1.0f,
    -1.0f, 1.0f, 1.0f,
    1.0f, 1.0f, 1.0f,
    -1.0f, 1.0f, 1.0f,
    1.0f, -1.0f, 1.0f
             ];

    uint vertex_buffer_id;

    glGenBuffers(1, &vertex_buffer_id);
    glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer_id);
    glBufferData(GL_ARRAY_BUFFER,
            float.sizeof * vertex_buffer_data.length,
            vertex_buffer_data.ptr,
            GL_STATIC_DRAW);

    auto projection = mat4.perspective(1024, 768, 90, 0.01, 100);
    auto view = mat4.look_at(vec3(4, 3, 3), vec3(0, 0, 0), vec3(0, 1, 0));
    auto model = mat4.identity;
    auto mvp = projection * view * model;

    auto program_id = load_shaders(vertex_source, fragment_source);

    uint mvp_id = glGetUniformLocation(program_id, "mvp");

    while (!glfwWindowShouldClose(window)) {
        glEnableVertexAttribArray(0);

        glBindBuffer(GL_ARRAY_BUFFER, vertex_buffer_id);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);

        glUseProgram(program_id);
        glUniformMatrix4fv(mvp_id, 1, false, mvp.value_ptr);
        glDrawArrays(GL_TRIANGLES, 0, to!int(vertex_buffer_data.length / 3));

        glDisableVertexAttribArray(0);


        glfwSwapBuffers(window);
        glfwPollEvents();

    }
}
