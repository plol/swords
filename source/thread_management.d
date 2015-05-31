
import core.time;

import std.experimental.logger;

import std.concurrency;

static import asynchronous;

private struct TimeToDie {}
private struct StartupReady(T) {}

struct Controller(T) {
    Tid tid;

    void kill() {
        tid.send(TimeToDie());
    }

    void send(string msg) {
        tid.send(msg);
    }
}

Controller!T spawn_thread(T, alias factory)() {
    auto ret = Controller!T(spawn(&run!(T, factory), thisTid));
    receive((StartupReady!T rdy) => log("StartupReady"));
    return ret;
}

void call_every(alias duration, alias f)(asynchronous.EventLoop loop) {
    void bounce() {
        f();
        loop.callLater(duration, &bounce);
    }
    bounce();
}

void run(T, alias factory)(Tid tid) {
    auto loop = asynchronous.getEventLoop();
    auto runner = factory(loop);

    call_every!(10.msecs, () => receiveTimeout(0.seconds, 
                (TimeToDie ttd) => loop.stop(),
                (string s) { log("got string ", s); }
                ))(loop);

    tid.send(StartupReady!T());
    loop.runForever();
}
