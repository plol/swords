
import core.time;

import std.experimental.logger;

import std.concurrency;

import async_stuff;

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

void run(T, alias factory)(Tid tid) {
    auto runner = factory();
    call_every(10.msecs,
            () { receiveTimeout(0.seconds, 
                                 (TimeToDie ttd) => stop_event_loop(),
                                 (string s) { log("got string ", s); }
                                ); });
    tid.send(StartupReady!T());
    run_event_loop_forever();
}
