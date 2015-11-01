
import core.time;

import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.typecons;

import std.experimental.logger;

import thread_management;
import networking;
import async_stuff;

import game;

import networking.protocol;

class Server {
    ServerNetworking networking;
    bool[size_t] got_frame_ok;

    UnitCommand[size_t] commands;

    Game game;

    this() {
        networking.initialize(&on_message);
        call_every(100.msecs, () => frame());

        game = new Game;

        auto player = game.create_player("Player 1");
        game.spawn_unit(player);
    }

    void frame() {
        foreach (idx, ref val; got_frame_ok) {
            if (!val) {
                log("problems.....");
            }
            val = false;
        }

        game.tick();

        foreach (idx, ref command; commands) {
            game.apply_command(command);
            command = UnitCommand();
        }

        broadcast(game.dlcmds);
    }

    void on_message(size_t connection_index, const(ubyte)[] data) {
        if (connection_index !in got_frame_ok) {
            got_frame_ok[connection_index] = false;
        }
        auto cmds = UplinkCommands(data);
        if (cmds.frame_ok.exists()) {
            got_frame_ok[connection_index] = true;
        }

        foreach (action; cmds.unit_actions) {
            commands[connection_index] = action;
        }
    }

    auto broadcast(StateDelta commands) {
        return networking.broadcast(commands.serialize());
    }
    auto broadcast(Chat chat) {
        StateDelta cmds;
        cmds.chat ~= chat;
        return broadcast(cmds);
    }
}

