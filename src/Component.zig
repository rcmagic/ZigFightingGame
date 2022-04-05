const math = @import("utils/math.zig");
pub const PhysicsComponent = struct {
    position: math.IntVector2D = .{},
    velocity: math.IntVector2D = .{},
    acceleration: math.IntVector2D = .{}
};