module networking;

import std.experimental.logger;

import networking.internals;


public import networking.server_connection;

class ClientConnection : MessageConnection {

    void delegate() frame;
    
    this(string server, size_t port) {
        super("client", new TcpConnection(server, port));

        frame = (){};
    }

    override
    void on_message(const(void)[] data) {
        if (cast(string) data == "FRAME!") {
            frame();
        } else {
            log(name, " messageReceived: ", cast(string)data);
        }
    }
}

ClientConnection connect_to_server(string server, size_t port) {
    auto client = new ClientConnection(server, port);

    return client;
}
