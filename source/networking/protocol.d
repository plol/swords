module networking.protocol;

import dproto.dproto;

mixin ProtocolBufferFromString!q{

    message Pos {
        optional int32 x = 1;
        optional int32 y = 2;
    }

    message UnitMoveCommand {
        enum ForwardMotion {
            FORWARD = 1;
            BACKWARD = 2;
        }

        enum LeftRightMotion {
            LEFT = 1;
            RIGHT = 2;
        }

        optional ForwardMotion forward = 1;
        optional LeftRightMotion strafe = 2;
        optional LeftRightMotion turn = 3;
    }

    message UnitCommand {
        enum Block {
            LEFT = 1;
            RIGHT = 2;
        }

        enum Attack {
            LEFT = 1;
            RIGHT = 2;
        }

        optional int32 unit_id = 1;

        optional UnitMoveCommand move = 2;
        optional Block block = 3;
        optional Attack attack = 4;
    }

    message UnitMovement {
        optional int32 unit_id = 1;
        optional Pos from = 2;
        optional Pos to = 3;
        optional int32 ticks = 4;
    }

    message ShowDebugBox {
        optional Pos low = 1;
        optional Pos high = 2;

        optional float altitude = 3;

        optional int32 duration_in_ticks = 4;
    }

    message Pause {
        optional bool pause = 1;
        optional bool unpause = 2;
    }

    message Chat {
        optional string player_name = 1;
        optional string time_stamp = 2;
        optional string message = 3;
    }

    message Frame {
        optional int64 frame_number = 1;
    }

    message UplinkCommands {
        optional Frame frame_ok = 1;
        repeated UnitCommand unit_actions = 2;
        optional Pause pause = 3;
        repeated Chat chat = 4;
    }

    message StateDelta {
        optional Frame frame_update = 1;
        repeated UnitMovement unit_actions = 2;
        optional Pause pause = 3;
        repeated Chat chat = 4;

        repeated ShowDebugBox debug_boxes = 5;
    }

};

