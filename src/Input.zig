pub const InputCommand = struct 
{
    Up: bool = false,
    Down: bool = false,
    Back: bool = false,
    Forward: bool = false,
    Attack: bool = false,

    // Reset inputs back to their default values
    pub fn Reset(self: *InputCommand) void 
    { 
        self.*  = InputCommand{};
    }
};