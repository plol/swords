module networking;

import std.string, std.range;
import std.experimental.logger;

import networking.internals;

import networking.protocol;

public import networking.server_connection;

class ClientConnection : MessageConnection {

    void delegate(StateDelta) on_command;
    
    this(TcpConnection conn) {
        super("client", conn);

        on_command = (string){};
    }

    override
    void on_message(const(ubyte)[] data) {
        on_command(StateDelta(data));
    }

    void write_commands(UplinkCommands cmds) {
        write(cmds.serialize());
    }
}

ClientConnection connect_to_server(string server, size_t port) {
    auto client = new ClientConnection(new TcpConnection(server, port));

    return client;
}


