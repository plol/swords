
import deimos.glfw.glfw3;
import derelict.opengl3.gl3;
import gl3n.linalg;

import engine;

struct Model {
    Buffer!vec3 vertex_buffer;
    Buffer!vec2 uv_buffer;

    vec3 pos;
    quat rotation;
    float scaling = 1;
}

struct Renderer {

    uint program_id;
    Uniform!mat4 mvp_uniform;
    Uniform!int sampler_uniform;

    void init() {
        program_id = load_shaders(vertex_source, fragment_source);

        mvp_uniform = create_uniform!mat4(program_id, "mvp");
        sampler_uniform = create_uniform!int(program_id, "myTextureSampler");
    }


    void render(mat4 vp, Model model, int n, uint texture_id) {
        auto m = mat4.translation(model.pos.x, model.pos.y, model.pos.z)
            * model.rotation.to_matrix!(4,4)()
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

}

