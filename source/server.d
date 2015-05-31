
import core.time;

import std.algorithm;
import std.conv;
import std.string;
import std.typecons;

import std.experimental.logger;

static import asynchronous;

import thread_management;
import networking;

class Server {
    ServerNetworking networking;
    asynchronous.Server async_server;

    this(asynchronous.EventLoop loop) {
        networking.data_received = &data_received;
        async_server = loop.createServer(&make_server_connection, "localhost", "12345");
        call_every!(100.msecs, () => broadcast("FRAME!"))(loop);
    }

    void data_received(size_t connection_index, const(void)[] data) {
        log("server received data on index ", connection_index,
                " with content \"", cast(string)(data), "\"");
        broadcast(text("client with index ", connection_index, " wrote me ",
                        cast(string)data));
    }

    auto make_server_connection() {
        return networking.make_server_connection();
    }
    auto broadcast(const(void)[] data) {
        return networking.broadcast(data);
    }
}

