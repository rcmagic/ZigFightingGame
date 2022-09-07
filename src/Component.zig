const math = @import("utils/math.zig");
pub const PhysicsComponent = struct {
    position: math.IntVector2D = .{},
    facingLeft: bool = false,
    facingOpponent: bool = false,
    velocity: math.IntVector2D = .{},
    acceleration: math.IntVector2D = .{}
};

pub const TimelineComponent = struct {
    framesElapsed: i32 = 0
};

pub const ReactionComponent = struct {
    hitStun: i32 = 0,
    hitStop: i32 = 0,
    knockBack: i32 = 0,
    attackHasHit: bool = false
};
