const math = @import("utils/math.zig");
const std = @import("std");
const input = @import("input.zig");

const INPUT_BUFFER_SIZE = 60;
pub const InputComponent = struct {
    input_command: input.InputCommand = .{},
    input_buffer: [INPUT_BUFFER_SIZE]input.InputCommand = [_]input.InputCommand{.{}} ** INPUT_BUFFER_SIZE,
    buffer_index: usize = INPUT_BUFFER_SIZE - 1,

    pub fn UpdateInput(self: *InputComponent, input_command: input.InputCommand) !void {
        self.*.buffer_index = (self.*.buffer_index + 1) % self.*.input_buffer.len;
        self.*.input_buffer[self.*.buffer_index] = input_command;
    }

    pub fn GetCurrentInputCommand(self: InputComponent) input.InputCommand {
        return self.input_buffer[self.buffer_index];
    }

    pub fn GetLastInputCommand(self: InputComponent) input.InputCommand {
        return self.input_buffer[(self.input_buffer.len + self.buffer_index - 1) % self.input_buffer.len];
    }

    pub fn IsInputHeld(self: InputComponent, inputName: input.InputNames, facingLeft: bool) bool {
        const currentInput = self.input_buffer[self.buffer_index];

        const Pressed: bool = switch (inputName) {
            .Up => currentInput.up,
            .Down => currentInput.down,
            .Left => currentInput.left,
            .Right => currentInput.right,
            .Back => if (facingLeft) currentInput.right else currentInput.left,
            .Forward => if (facingLeft) currentInput.left else currentInput.right,
            .Attack => currentInput.attack,
        };

        return Pressed;
    }

    pub fn WasInputPressedOnFrame(self: InputComponent, inputName: input.InputNames, frame: usize, facingLeft: bool) bool {
        const bufferIndex: usize = frame % self.input_buffer.len;
        const lastBufferIndex: usize = (self.input_buffer.len + frame - 1) % self.input_buffer.len;

        const currentInput = self.input_buffer[bufferIndex];
        const lastInput = self.input_buffer[lastBufferIndex];

        const left_check: bool = currentInput.left and !lastInput.left;
        const right_check: bool = currentInput.right and !lastInput.right;

        const Pressed: bool = switch (inputName) {
            .Up => currentInput.up and !lastInput.up,
            .Down => currentInput.down and !lastInput.down,
            .Left => currentInput.left and !lastInput.left,
            .Right => currentInput.right and !lastInput.right,
            .Back => if (facingLeft) right_check else left_check,
            .Forward => if (facingLeft) left_check else right_check,
            .Attack => currentInput.attack and !lastInput.attack,
        };

        return Pressed;
    }

    pub fn WasInputPressedBuffered(self: InputComponent, inputName: input.InputNames, duration: usize, facingLeft: bool) bool {
        var i: usize = 0;
        while (i < duration) : (i += 1) {
            if (self.WasInputPressedOnFrame(inputName, self.input_buffer.len + self.buffer_index - i, facingLeft)) {
                return true;
            }
        }

        return false;
    }

    pub fn WasInputPressed(self: InputComponent, inputName: input.InputNames, facingLeft: bool) bool {
        const currentInput = self.GetCurrentInputCommand();
        const lastInput = self.GetLastInputCommand();

        const left_check: bool = currentInput.left and !lastInput.left;
        const right_check: bool = currentInput.right and !lastInput.right;

        const Pressed: bool = switch (inputName) {
            .Up => currentInput.up and !lastInput.up,
            .Down => currentInput.down and !lastInput.down,
            .Left => currentInput.left and !lastInput.left,
            .Right => currentInput.right and !lastInput.right,
            .Back => if (facingLeft) right_check else left_check,
            .Forward => if (facingLeft) left_check else right_check,
            .Attack => currentInput.attack and !lastInput.attack,
        };

        return Pressed;
    }

    pub fn WasMotionExecuted(self: InputComponent, motionName: input.MotionNames, timeLimit: usize, facingLeft: bool) bool {
        var adjustLimit: usize = timeLimit;

        if (adjustLimit > (self.input_buffer.len + self.buffer_index)) {
            adjustLimit = self.input_buffer.len + self.buffer_index;
        }

        var CurrentMotionIndex: usize = 0;

        const MotionList = input.MotionInputs[@intFromEnum(motionName)];

        for (0..adjustLimit) |count| {
            const buffer_position: usize = (self.input_buffer.len + self.buffer_index - (adjustLimit - 1) + count) % self.input_buffer.len;
            const input_command = self.input_buffer[buffer_position];
            if (input.CheckNumpadDirection(input_command, MotionList[CurrentMotionIndex], facingLeft)) {
                std.debug.print("Detected Motion Direction {}\n", .{MotionList[CurrentMotionIndex]});
                CurrentMotionIndex = CurrentMotionIndex + 1;

                if (CurrentMotionIndex >= MotionList.len) {
                    return true;
                }
            }
        }
        return false;
    }
};

pub const PhysicsComponent = struct {
    position: math.IntVector2D = .{},
    facingLeft: bool = false,
    facingOpponent: bool = false,
    velocity: math.IntVector2D = .{},
    acceleration: math.IntVector2D = .{},

    pub fn SetForwardSpeed(self: *PhysicsComponent, Speed: i32) void {
        self.velocity.x = if (self.facingLeft) -Speed else Speed;
    }
};

pub const TimelineComponent = struct { framesElapsed: i32 = 0 };

pub const ReactionComponent = struct {
    hitStun: i32 = 0,
    guardStun: i32 = 0,
    hitStop: i32 = 0,
    knockBack: i32 = 0,
    airKnockback: i32 = 0,
    launchVelocityY: i32 = 0,
    attackHasHit: bool = false,
    attackHasHitForSpecialCancel: bool = false,
    grabLocked: bool = false,
};

pub const StatsComponent = struct {
    totalHitStun: i32 = 0,
    totalGuardStun: i32 = 0,
};

const JumpFlags = enum(u32) {
    None,
    JumpForward,
    JumpBack,
};

pub const ActionFlagsComponent = struct {
    jumpFlags: JumpFlags = JumpFlags.None,
};
