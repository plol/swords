
module engine.window_management;

import std.stdio;
import std.string;
import std.exception;
import std.conv;
import std.utf;
import std.range; import std.experimental.logger;
import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;
import imageformats;
import backtrace;

import engine.graphics;

struct Window {
    GLFWwindow* window;

    bool should_continue() {
        return !glfwWindowShouldClose(window);
    }

    void swap_buffers() {
        check_error();
        glfwSwapBuffers(window);
        glfwPollEvents();
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        check_error();
    }


    bool is_key_pressed(string key) {
        if (key.length == 1) {
            return glfwGetKey(window, key[0]) == GLFW_PRESS;
        }
        assert (0);
    }
}

Window create_window() {

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

    return Window(window);
}

