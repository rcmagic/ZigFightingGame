
pub const InputNames = enum(u32) {
    Up,
    Down,
    Left,
    Right,
    Back,
    Forward,
    Attack
};

pub const InputCommand = struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    back: bool = false,
    forward: bool = false,
    attack: bool = false,

    // Reset inputs back to their default values
    pub fn reset(self: *InputCommand) void {
        self.* = InputCommand{};
    }
};
