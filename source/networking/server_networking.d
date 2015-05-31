module networking.server_connection;

import std.conv;
import std.string;

import networking.internals;


class ServerConnection : BasicConnection {
    size_t index;
    void delegate(size_t, const(void)[]) callback;

    this(size_t connection_index, void delegate(size_t, const(void)[]) data_received_cb) {
        super("ServerConnection with index %s".format(connection_index));
        index = connection_index;
        callback = data_received_cb;
    }

    override void messageReceived(const(void)[] data) {
        callback(index, data);
    }
}

struct ServerNetworking {

    ServerConnection[] server_connections;

    void delegate(size_t, const(void)[]) data_received;

    asynchronous.Protocol make_server_connection() {
        auto connection_index = server_connections.length;
        auto sc = new ServerConnection(connection_index, data_received);
        server_connections ~= sc;
        return sc;
    }

    void send_to(size_t index, const(void)[] data) {
        server_connections[index].write(data);
    }

    void broadcast(const(void)[] data) {
        foreach (c; server_connections) {
            c.write(data);
        }
    }
}

