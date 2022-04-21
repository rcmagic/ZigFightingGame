const math = @import("utils/math.zig");
pub const PhysicsComponent = struct {
    position: math.IntVector2D = .{},
    velocity: math.IntVector2D = .{},
    acceleration: math.IntVector2D = .{}
};


pub const HitEvent = struct
{
    attacker: usize,
    defender: usize
};

const MAX_HIT_EVENTS_PER_ENTITY = 10;
pub const HitEventComponent = struct
{
    events: [MAX_HIT_EVENTS_PER_ENTITY] HitEvent = [MAX_HIT_EVENTS_PER_ENTITY]**.{.attacker = 0, .defender = 0 },
    eventCount: usize = 0
};