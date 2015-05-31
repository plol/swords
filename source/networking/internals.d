module networking.internals;

import std.experimental.logger;
import std.algorithm;
import std.conv;

static import asynchronous;

struct MessageBuffer {
    void[] buffer;

    void add_data(const void[] data) {
        buffer ~= data;
    }

    uint next_msg_length() const {
        if (buffer.length < uint.sizeof) {
            return uint.max;
        }
        return (cast(uint[])(buffer[0 .. uint.sizeof]))[0] + cast(uint)uint.sizeof;
    }

    inout(void)[] front() @property inout {
        return buffer[uint.sizeof .. next_msg_length()];
    }
    void popFront() {
        auto len = next_msg_length();
        buffer[0 .. $ - len][] = buffer[len .. $];
        buffer.length -= len;
        buffer.assumeSafeAppend();
        log(buffer.length);
    }
    bool empty() const {
        return next_msg_length() > buffer.length;
    }
}

class BasicConnection : asynchronous.Protocol {
    asynchronous.Transport transport;
    string name;
    MessageBuffer buffer;

    this(string connection_name) {
        name = connection_name;
    }

    void write(const(void)[] data) {
        uint len = to!uint(data.length);
        transport.write((&len)[0..1]);
        transport.write(data);
    }

    void connectionMade(asynchronous.BaseTransport base) {
        transport = cast(typeof(transport)) base; // wtf?
        log(name, " connectionMade");
    }

    void connectionLost(Exception exception) {
        log(name, " connectionLost");
    }

    void pauseWriting() {
        log(name, " pauseWriting");
    }

    void resumeWriting() {
        log(name, " resumeWriting");
    }

    void dataReceived(const(void)[] data) {
        log(name, " dataReceived ", data.length);

        buffer.add_data(data);
        foreach (msg; buffer) {
            messageReceived(msg);
        }
    }

    void messageReceived(const(void)[] data) {
        log(name, " messageReceived: ", cast(string)data);
    }


    bool eofReceived() {
        log(name, " eofReceived");
        return false;
    }
}

