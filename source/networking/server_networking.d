module networking.server_connection;

import std.conv;
import std.string;

import networking.internals;

import async_stuff;


class ServerConnection : MessageConnection {
    size_t index;
    void delegate(size_t, const(ubyte)[]) callback;

    this(TcpConnection connection, size_t connection_index,
            void delegate(size_t, const(ubyte)[]) on_message) {
        super("ServerConnection with index %s".format(connection_index), connection);
        index = connection_index;
        callback = on_message;
    }

    override void on_message(const(ubyte)[] data) {
        callback(index, data);
    }
}

struct ServerNetworking {

    ServerConnection[] server_connections;
    TcpServer listener;

    void delegate(size_t, const(ubyte)[]) on_message;

    void initialize(void delegate(size_t, const(ubyte)[]) on_message) {
        this.on_message = on_message;
        listener = new TcpServer;

        listener.on_connect = &on_connect;
        listener.listen_on("localhost", 12345);
    }

    void on_connect(TcpConnection conn) {
        auto connection_index = server_connections.length;
        auto sc = new ServerConnection(conn, connection_index, on_message);
        server_connections ~= sc;
    }

    void send_to(size_t index, const(ubyte)[] data) {
        server_connections[index].write(data);
    }

    void broadcast(const(ubyte)[] data) {
        foreach (c; server_connections) {
            c.write(data);
        }
    }
}

