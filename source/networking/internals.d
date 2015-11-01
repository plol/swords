module networking.internals;

import std.experimental.logger;
import std.algorithm;
import std.conv;

public import async_stuff;

class MessageBuffer {
    ubyte[] buffer;

    void add_data(const ubyte[] data) {
        buffer ~= data;
    }

    uint next_msg_length() const {
        if (buffer.length < uint.sizeof) {
            return uint.max;
        }
        return (cast(uint[])(buffer[0 .. uint.sizeof]))[0] + cast(uint)uint.sizeof;
    }

    inout(ubyte)[] front() @property inout {
        return buffer[uint.sizeof .. next_msg_length()];
    }
    void popFront() {
        auto len = next_msg_length();
        copy(buffer[len .. $], buffer[0 .. $-len]);
        buffer.length -= len;
        buffer.assumeSafeAppend();
    }
    bool empty() const {
        return next_msg_length() > buffer.length;
    }
}

class MessageConnection {
    string name;
    MessageBuffer buffer;

    TcpConnection connection;

    this(string connection_name, TcpConnection tcp_connection) {
        name = connection_name;
        buffer = new MessageBuffer;
        connection = tcp_connection;
        tcp_connection.on_read = &on_data;
    }

    void write(const(ubyte)[] data) {
        uint len = to!uint(data.length);
        auto msg_length = uint.sizeof + len;

        auto write_buffer = new ubyte[](msg_length);

        write_buffer[0 .. uint.sizeof][] = cast(ubyte[])((&len)[0..1])[];
        write_buffer[uint.sizeof .. msg_length][] = cast(ubyte[])data[];

        //log(name, " sending ", len, " ", msg_length, " ", write_buffer);
        connection.write(write_buffer[0 .. msg_length]);
    }

    void on_data(const(ubyte)[] data) {
        buffer.add_data(data);
        foreach (msg; buffer) {
            on_message(msg);
        }
    }

    void on_message(const(ubyte)[] data) {
        log(name, " on_message: ", cast(string)data);
    }
}

