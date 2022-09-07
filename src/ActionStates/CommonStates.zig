const std = @import("std");
const StateMachine = @import("StateMachine.zig");


// When the character collides with the ground, return to ground states.
fn HandleGroundCollision(context: *StateMachine.CombatStateContext) bool
{
    if(context.PhysicsComponent.velocity.y < 0 and context.PhysicsComponent.position.y <= 0)
    {
        context.PhysicsComponent.position.y = 0;
        context.PhysicsComponent.velocity.y = 0;
        context.PhysicsComponent.acceleration.y = 0;

        context.bTransition = true;
        context.NextState = StateMachine.CombatStateID.Standing;

        return true;
    }

    return false;
}


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
        context.PhysicsComponent.velocity.x = 0;

        if(context.InputCommand.Right)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.WalkingForward;
        }
        else if(context.InputCommand.Left)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.WalkingBackward;
        }
        else if(context.InputCommand.Up)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.Jump;   
        }
        else if(context.InputCommand.Attack)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.Attack;
        }

        // Flip the character to face the opponent.
        if(!context.PhysicsComponent.facingOpponent)
        {
            context.PhysicsComponent.facingLeft = !context.PhysicsComponent.facingLeft;
            context.PhysicsComponent.facingOpponent = true;
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
        context.PhysicsComponent.velocity.x = 2000;        

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

pub const WalkingBackward = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("WalkingBackward.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;

        //  Move the character right when the player presses right on the controller.
        context.PhysicsComponent.velocity.x = -2000;        

        if(!context.InputCommand.Left)
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.Standing;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("WalkingBackward.OnEnd()\n", .{});
    }
};


pub const Jump = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Jump.OnStart()\n", .{});

        // Only initialize jump velocity when on the ground.
        if(context.PhysicsComponent.position.y <= 0)
        {
            context.PhysicsComponent.velocity.y = 10000;
        }

        context.PhysicsComponent.acceleration.y = -260;
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
   
        if(HandleGroundCollision(context))
        {
            return;
        }

        if(context.InputCommand.Attack) 
        {
            context.bTransition = true;
            context.NextState = StateMachine.CombatStateID.Attack;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Jump.OnEnd()\n", .{});
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

        if(context.ActionData) | actionData |
        {
            if(HandleGroundCollision(context))
            {
                return;
            }

            if(context.TimelineComponent.framesElapsed >= actionData.Duration)
            {
                context.bTransition = true;

                if(context.PhysicsComponent.position.y > 0)
                {
                     context.NextState = StateMachine.CombatStateID.Jump;
                }
                else 
                {
                    context.NextState = StateMachine.CombatStateID.Standing;
                }
            }
        }

    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Attack.OnEnd()\n", .{});
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


pub const Reaction = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Reaction.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("Reaction.OnEnd()\n", .{});
    }
};