import std.stdio;
import std.range;
import std.algorithm;

import libasync;

shared static ~this() {
    destroyAsyncThreads();
}


EventLoop event_loop() {
    static EventLoop thread_local_event_loop;
    if (thread_local_event_loop is null) {
        thread_local_event_loop = new EventLoop;
    }
    return thread_local_event_loop;
}

bool should_keep_running_event_loop;

void stop_event_loop() {
    should_keep_running_event_loop = false;
}

void run_event_loop_forever() {
    should_keep_running_event_loop = true;
    while (should_keep_running_event_loop) {
        event_loop().loop();
    }
}


final class TcpConnection {

    AsyncTCPConnection connection;

    void delegate(const(ubyte)[]) on_read;

    this(AsyncTCPConnection c) {
        connection = c;
    }

    this(string host, size_t port) {
        this(new AsyncTCPConnection(event_loop()));
        if (!connection.host(host, port).run(&on_tcp_event))
            writeln(connection.status);
    }
    void write(const ubyte[] data) {
        connection.send(data);
    }

    private void on_tcp_event(TCPEvent ev) {
        try final switch (ev) {
            case TCPEvent.CONNECT:
                break;
            case TCPEvent.READ:
                receive_entire_message();
                break;
            case TCPEvent.WRITE:
                break;
            case TCPEvent.CLOSE:
                break;
            case TCPEvent.ERROR:
                break;
        } catch (Throwable t) {
            writeln(t);
        }
    }
    private void receive_entire_message() {
        ubyte[] buf;
        while (true) {
            ubyte[128] mini_buf;
            ubyte[] ffs = mini_buf[];
            auto count = connection.recv(ffs);
            buf ~= mini_buf[0 .. count];
            if (count < 128) {
                on_read(buf);
                break;
            }
        }
    }
}

class TcpServer {

    AsyncTCPListener listener;

    void delegate(TcpConnection) on_connect;

    this() {
        listener = new AsyncTCPListener(event_loop());
        on_connect = (a) { writeln("FKIN HELL M8"); };
    }

    void listen_on(string address, size_t port) {
        auto ok = listener.host(address, port).run((AsyncTCPConnection a) {
                auto conn = new TcpConnection(a);
                on_connect(conn);
                return &conn.on_tcp_event;
        });
    }
}

TcpConnection connect(string host, size_t port) {
    return new TcpConnection(host, port);
}

void call_every(Duration dur, void delegate() dg) {
    auto timer = new AsyncTimer(event_loop());
    timer.periodic(true);
    timer.duration(dur);
    timer.run(dg);
}

void call_soon(Duration dur, void delegate() dg) {
    auto timer = new AsyncTimer(event_loop());
    timer.periodic(false);
    timer.duration(dur);
    timer.run(dg);
}

