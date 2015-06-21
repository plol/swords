
import core.time;

import std.algorithm;
import std.conv;
import std.string;
import std.typecons;

import std.experimental.logger;

import thread_management;
import networking;
import async_stuff;

class Server {
    ServerNetworking networking;

    this() {
        networking.initialize(&on_message);
        call_every(100.msecs, () => broadcast("FRAME!"));
        call_every(100.msecs, () => broadcast("horsie pie"));
    }

    void on_message(size_t connection_index, const(void)[] data) {
        log("server received data on index ", connection_index,
                " with content \"", cast(string)(data), "\"");
        broadcast(text("client with index ", connection_index, " wrote me ",
                        cast(string)data));
    }

    auto broadcast(const(void)[] data) {
        return networking.broadcast(data);
    }
}

