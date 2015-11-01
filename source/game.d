import std.conv;
import std.experimental.logger;

import protocol = networking.protocol;

struct ID(T) {
    long value;

    static long id_counter;
    static ID next() { return ID(++id_counter); }

    static ID from_number(long value) {
        return ID(value);
    }
}

struct Pos {
    int x;
    int y;

    static Pos from_protocol_pos(protocol.Pos pos) {
        return Pos(pos.x, pos.y);
    }

    protocol.Pos to_protocol_pos() {
        auto pos = protocol.Pos();
        pos.x = x;
        pos.y = y;
        return pos;
    }

    Vec2d opBinary(string op)(Pos p) if (op == "-") {
        return Vec2d(x - p.x, y - p.y);
    }
    Pos opBinary(string op)(Vec2d v) if (op == "-" || op == "+") {
        return mixin("Pos(x "~op~" v.x, y "~op~" v.y)");
    }
}

struct Vec2d {
    int x;
    int y;
}

struct Player {
    string name;
}

struct Grid {
    Unit[][Pos] units;
}

enum Facing {
    east,
    north,
    west,
    south,
}

Vec2d strafe_delta(protocol.UnitMoveCommand.LeftRightMotion strafe, Facing facing) {
    final switch (strafe) {
        case protocol.UnitMoveCommand.LeftRightMotion.LEFT:
            final switch (facing) {
                case Facing.east: return Vec2d(0, -1);
                case Facing.north: return Vec2d(-1, 0);
                case Facing.west: return Vec2d(0, 1);
                case Facing.south: return Vec2d(1, 0);
            }
        case protocol.UnitMoveCommand.LeftRightMotion.RIGHT:
            final switch (facing) {
                case Facing.east: return Vec2d(0, 1);
                case Facing.north: return Vec2d(1, 0);
                case Facing.west: return Vec2d(0, -1);
                case Facing.south: return Vec2d(-1, 0);
            }
    }
}

Vec2d forward_delta(protocol.UnitMoveCommand.ForwardMotion forward, Facing facing) {
    final switch (forward) {
        case protocol.UnitMoveCommand.ForwardMotion.FORWARD:
            final switch (facing) {
                case Facing.east: return Vec2d(1, 0);
                case Facing.north: return Vec2d(0, -1);
                case Facing.west: return Vec2d(-1, 0);
                case Facing.south: return Vec2d(0, 1);
            }
        case protocol.UnitMoveCommand.ForwardMotion.BACKWARD:
            final switch (facing) {
                case Facing.east: return Vec2d(-1, 0);
                case Facing.north: return Vec2d(0, -1);
                case Facing.west: return Vec2d(1, 0);
                case Facing.south: return Vec2d(0, -1);
            }
    }
}



Pos strafe(Pos pos, protocol.UnitMoveCommand.LeftRightMotion strafe, Facing facing) {
    return pos + strafe_delta(strafe, facing);
}

Facing turn(Facing facing, protocol.UnitMoveCommand.LeftRightMotion turn) {
    final switch (turn) {
        case protocol.UnitMoveCommand.LeftRightMotion.LEFT:
            final switch (facing) {
                case Facing.east: return Facing.north;
                case Facing.north: return Facing.west;
                case Facing.west: return Facing.south;
                case Facing.south: return Facing.east;
            }
        case protocol.UnitMoveCommand.LeftRightMotion.RIGHT:
            final switch (facing) {
                case Facing.east: return Facing.south;
                case Facing.north: return Facing.east;
                case Facing.west: return Facing.north;
                case Facing.south: return Facing.west;
            }
    }
}

Pos forward(Pos pos, protocol.UnitMoveCommand.ForwardMotion forward, Facing facing) {
    return pos + forward_delta(forward, facing);
}


struct Unit {
    ID!Player player;
    Pos pos;
    Pos moving_towards;

    Facing facing;

    int ticks_for_move;
}

class Game {
    Player[ID!Player] players;
    Unit[ID!Unit] units;
    Grid grid;

    long frame_number;

    protocol.StateDelta dlcmds;

    ID!Player create_player(string player_name) {
        auto id = ID!Player.next();
        players[id] = Player(player_name);
        return id;
    }

    ID!Unit spawn_unit(ID!Player owner) {
        auto id = ID!Unit.next();
        auto unit = Unit(owner, Pos(0, 0));
        units[id] = unit;
        grid.units[unit.pos] ~= unit;
        return id;
    }

    void tick() {
        log("tick");

        dlcmds = protocol.StateDelta();
        dlcmds.frame_update = protocol.Frame();
        dlcmds.frame_update.frame_number = ++frame_number;

        foreach (id, ref unit; units) {
            log("doin unit ", id);
            if (unit.pos != unit.moving_towards) {
                log("movin");
                assert (unit.ticks_for_move > 0);
                unit.ticks_for_move -= 1;
                if (unit.ticks_for_move == 0) {
                    unit.pos = unit.moving_towards;
                }
            } else {
                log("stayin still");
                assert (unit.ticks_for_move == 0);
            }
        }
    }

    void apply_command(protocol.UnitCommand action) {

        if (!action.unit_id.exists()) {
            log("unit id does not exist");
            return;
        }

        auto id = ID!Unit.from_number(action.unit_id);
        auto unit = id in units;

        if (unit is null) {
            log("unit not found in game");
            return;
        }

        if (action.move.exists()) {
            auto move = action.move;
            if (unit.ticks_for_move != 0) {
                log("unit already busy moving, ticks left: ",
                        unit.ticks_for_move);
                return;
            }

            auto new_pos = unit.pos;

            if (action.move.strafe.exists()) {
                new_pos = new_pos.strafe(action.move.strafe, unit.facing);
            }
            if (action.move.forward.exists()) {
                new_pos = new_pos.forward(action.move.forward, unit.facing);
            }

            auto new_facing = unit.facing;
            if (action.move.turn.exists()) {
                new_facing = unit.facing.turn(action.move.turn);
            }

            if (new_pos == unit.pos) {
                log("move to same positiion meaningless :s");
                return;
            }

            unit.moving_towards = new_pos;

            auto old_pos = unit.pos;

            if (old_pos.x == new_pos.x || old_pos.y == new_pos.y) {
                unit.ticks_for_move = 2;
            } else {
                unit.ticks_for_move = 3;
            }

            protocol.UnitMovement movement;
            movement.unit_id = to!int(id.value);
            movement.from = old_pos.to_protocol_pos();
            movement.to = unit.moving_towards.to_protocol_pos();
            movement.ticks = unit.ticks_for_move;

            dlcmds.unit_actions ~= movement;

            return;
        }
        if (action.block.exists()) {
        }
        if (action.attack.exists()) {
        }
    }

    protocol.ShowDebugBox show_debug_box(Pos low, Pos high, float altitude, int ticks) {
        auto box = protocol.ShowDebugBox();
        box.low = low.to_protocol_pos();
        box.high = high.to_protocol_pos();
        box.altitude = altitude;
        box.duration_in_ticks = ticks;
        return box;
    }
}




