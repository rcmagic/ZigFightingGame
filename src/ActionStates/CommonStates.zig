const std = @import("std");

// Standing state
const Standing = struct 
{
    pub fn OnStart() void
    {
        std.debug.print("Standing.OnStart()\n");
    }

    pub fn OnUpdate() void
    {
        std.debug.print("Standing.OnUpdate()\n");
    }

    pub fn OnEnd() void
    {
        std.debug.print("Standing.OnEnd()\n");
    }
};

const Crouching = struct 
{
    pub fn OnStart() void
    {
        std.debug.print("Crouching.OnStart()\n");
    }

    pub fn OnUpdate() void
    {
        std.debug.print("Crouching.OnUpdate()\n");
    }

    pub fn OnEnd() void
    {
        std.debug.print("Crouching.OnEnd()\n");
    }
};