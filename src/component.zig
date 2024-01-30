const math = @import("utils/math.zig");
const std = @import("std");
const input = @import("input.zig");


const INPUT_BUFFER_SIZE = 60;
pub const InputComponent = struct 
{ 
    input_command: input.InputCommand = .{},
    input_buffer: [INPUT_BUFFER_SIZE]input.InputCommand = [_]input.InputCommand{.{}} ** INPUT_BUFFER_SIZE,
    buffer_index: usize = INPUT_BUFFER_SIZE-1,

    pub fn UpdateInput(self: *InputComponent, input_command: input.InputCommand) !void
    {
        self.*.buffer_index = (self.*.buffer_index + 1) % self.*.input_buffer.len;
        self.*.input_buffer[self.*.buffer_index] = input_command;
    }

    pub fn GetCurrentInputCommand(self: InputComponent) input.InputCommand
    {
        return self.input_buffer[self.buffer_index];
    }

    pub fn GetLastInputCommand(self: InputComponent) input.InputCommand
    {
        return self.input_buffer[ (self.input_buffer.len + self.buffer_index-1) % self.input_buffer.len];
    }


    pub fn WasInputPressed(self: InputComponent, inputName: input.InputNames ) bool
    {
        var currentInput = self.GetCurrentInputCommand();
        var lastInput = self.GetLastInputCommand();
        const Pressed : bool = switch(inputName)
        {
            .Up => currentInput.up and !lastInput.up,
            .Down => currentInput.down and !lastInput.down,
            .Left => currentInput.left and !lastInput.left,
            .Right => currentInput.right and !lastInput.right,
            .Back => currentInput.back and !lastInput.back,
            .Forward => currentInput.forward and !lastInput.forward,
            .Attack => currentInput.attack and !lastInput.attack,
        };

        return Pressed;
    }

    pub fn WasMotionExecuted(self: InputComponent, motionName: input.MotionNames, timeLimit: usize ) bool
    {
        var adjustLimit : usize = timeLimit;

        if(adjustLimit > (self.input_buffer.len + self.buffer_index))
        {
            adjustLimit = self.input_buffer.len + self.buffer_index;
        }

        var BufferStart : usize = (self.input_buffer.len + self.buffer_index - adjustLimit) % self.input_buffer.len;

        var CurrentMotionIndex : usize = 0;

        const MotionList = input.MotionInputs[@enumToInt(motionName)];

        _ = BufferStart;
        for(self.input_buffer) | input_command |
        {
            std.debug.print("Checking Motion Direction {}\n", .{MotionList[CurrentMotionIndex]});
            if(input.CheckNumpadDirection(input_command, MotionList[CurrentMotionIndex] ))
            {
                std.debug.print("Detected Motion Direction {}\n", .{MotionList[CurrentMotionIndex]});
                CurrentMotionIndex = CurrentMotionIndex + 1;

                if(CurrentMotionIndex >= MotionList.len)
                {
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
    attackHasHit: bool = false 
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
    jumpFlags: JumpFlags = JumpFlags.None 
};
