const std = @import("std");
const StateMachine = @import("StateMachine.zig");

// Standing state
pub const Standing = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Standing.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;

        //  Stop character movement on standing.
        if(context.PhysicsComponent) | physicsComponent |
        {
            physicsComponent.velocity.x = 0;
        }

        if(context.InputCommand.Right)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.WalkingForward;
        }
        else  if(context.InputCommand.Attack)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.Attack;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Standing.OnEnd()\n", .{});
    }
};

pub const WalkingForward = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("WalkingForward.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;

        //  Move the character right when the player presses right on the controller.
        if(context.PhysicsComponent) | physicsComponent |
        {
            physicsComponent.velocity.x = 2000;
        }

        if(!context.InputCommand.Right)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.Standing;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("WalkingForward.OnEnd()\n", .{});
    }
};


pub const Attack = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Attack.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;

        if(context.TimelineComponent) | timeline |
        {
            if(context.ActionData) | actionData |
            {
                if(timeline.framesElapsed >= actionData.Duration)
                {
                    context.bTransition = true;
                    context.NextState = StateMachine.CombatStateID.Standing;
                }
            }
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("WalkingForward.OnEnd()\n", .{});
    }
};


const Crouching = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Crouching.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Crouching.OnUpdate()\n", .{});
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Crouching.OnEnd()\n", .{});
    }
};