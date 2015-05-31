module networking;

import std.experimental.logger;

import networking.internals;

public import networking.server_connection;

class ClientConnection : BasicConnection {
    this(string name) {
        super(name);
    }
}
