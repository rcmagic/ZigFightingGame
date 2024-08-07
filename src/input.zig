pub const InputNames = enum(u32) { Up, Down, Left, Right, Back, Forward, Attack };

pub const MotionNames = enum(u32) {
    None,
    QCF, // ↓↘→
    QCB, // ↓↙←
    DP, // →↓↘
    RDP, // ←↓↙
    Last,
};

// const int32 MotionInputs [][] =
// {
//     { 2, 3 6},
//     {2, 1, 4},
//     {6, 2, 3},
//     {4, 2, 1}
// };

pub const MotionInputs = [@intFromEnum(MotionNames.Last)][3]u32{
    [_]u32{ 0, 0, 0 },
    [_]u32{ 2, 3, 6 },
    [_]u32{ 2, 1, 4 },
    [_]u32{ 6, 2, 3 },
    [_]u32{ 4, 2, 1 },
};

pub const InputCommand = struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    attack: bool = false,

    // Reset inputs back to their default values
    pub fn reset(self: *InputCommand) void {
        self.* = InputCommand{};
    }
};

pub fn CheckNumpadDirection(input_command: InputCommand, numpad_direction: u32, facingLeft: bool) bool {
    const back: bool = if (facingLeft) input_command.right else input_command.left;
    const forward: bool = if (facingLeft) input_command.left else input_command.right;
    return switch (numpad_direction) {
        1 => back and input_command.down,
        2 => input_command.down and !(input_command.left or input_command.right),
        3 => forward and input_command.down,
        4 => back and !(input_command.up or input_command.down),
        6 => forward and !(input_command.up or input_command.down),
        7 => back and input_command.up,
        8 => input_command.up and !(input_command.left or input_command.right),
        9 => forward and input_command.up,
        else => false,
    };
}
