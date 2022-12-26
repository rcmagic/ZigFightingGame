const std = @import("std");
const StateMachine = @import("StateMachine.zig");
const component = @import("../component.zig");
const common = @import("../common.zig");

// When the character collides with the ground, return to ground states.
fn HandleGroundCollision(context: *StateMachine.CombatStateContext) bool
{
    if(context.physics_component.velocity.y < 0 and context.physics_component.position.y <= 0)
    {
        context.physics_component.position.y = 0;
        context.physics_component.velocity.y = 0;
        context.physics_component.acceleration.y = 0;

        context.TransitionToState(.Standing);

        return true;
    }

    return false;
}



fn CommonJumpTransitions(context: *StateMachine.CombatStateContext) bool
{
    if(context.input_command.up)
    {
        context.action_flags_component.jumpFlags = .None;

        if(context.input_command.forward)
        {
            context.action_flags_component.jumpFlags = .JumpForward;
        }
        else if(context.input_command.back)
        {
            context.action_flags_component.jumpFlags = .JumpBack;
        }

        context.TransitionToState(.Jump);
        
        return true;
    }

    return false;
}


fn CommonAttackTransitions(context: *StateMachine.CombatStateContext) bool
{
    if(context.input_command.attack)
    {
        context.TransitionToState(.Attack);
        return true;
    }

    return false;
}

fn CommonTransitions(context: *StateMachine.CombatStateContext) bool
{
    if(CommonAttackTransitions(context))
    {
        return true;
    }
    else if(CommonJumpTransitions(context))
    {
        return true;
    }
    else if(context.input_command.forward)
    {
        context.TransitionToState(.WalkingForward);
        return true;
    }
    else if(context.input_command.back)
    {
        context.TransitionToState(.WalkingBackward);
        return true;
    }

    return false;

}

pub fn CommonToIdleTransitions(context: *StateMachine.CombatStateContext) void
{
    if(CommonTransitions(context))
    {
        return;
    }

    if(context.physics_component.position.y > 0) 
    {
        context.TransitionToState(.Jump);
    }
    else
    {
        context.TransitionToState(.Standing);
    }

    context.bTransition = true;
}

fn TriggerEndOfAttackTransition(context: *StateMachine.CombatStateContext) bool
{
    if(context.ActionData) | actionData |
    {
        // Only check for idle action transitions on the final frame.
        if(context.timeline_component.framesElapsed >= actionData.duration)
        { 
            CommonToIdleTransitions(context);
            return true;
        }
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
        context.physics_component.velocity.x = 0;

        if(CommonTransitions(context))
        {
            return;
        }

        // automatically turn the character to face the opponent when they've changed sides
        common.flip_to_face_opponent(context.physics_component);
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


        const WalkingForwardSpeed = 2000;
        context.physics_component.SetForwardSpeed(WalkingForwardSpeed);

        if(CommonAttackTransitions(context))
        {
            return; // Bail out of this state when a transition has been detected
        }
        else if(CommonJumpTransitions(context))
        {
            return; // Bail out of this state when a transition has been detected
        }
        else if(context.input_command.back)
        {
            context.TransitionToState(.WalkingBackward);
            return;
        }


        if(!context.input_command.forward)
        {
            context.TransitionToState(.Standing);
        }

        common.flip_to_face_opponent(context.physics_component);
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

        if(CommonAttackTransitions(context))
        {
            return; // Bail out of this state when a transition has been detected
        }
        else if(CommonJumpTransitions(context))
        {
            return; // Bail out of this state when a transition has been detected
        }
        else if(context.input_command.forward)
        {
            context.TransitionToState(.WalkingForward);
            return;
        }


        const WalkingBackSpeed = -2000;
        context.physics_component.SetForwardSpeed(WalkingBackSpeed);

        if(!context.input_command.back)
        {
             context.TransitionToState(.Standing);
        }

        common.flip_to_face_opponent(context.physics_component);
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
        if(context.physics_component.position.y <= 0)
        {
            context.physics_component.velocity.y = 10000;
        }

        context.physics_component.acceleration.y = -260;

        const ForwardSpeed : i32 = switch(context.action_flags_component.jumpFlags)
        {
            .None => 0,
            .JumpForward => 1000,
            .JumpBack => -1000,
        };

        context.physics_component.SetForwardSpeed(ForwardSpeed);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
   
        if(HandleGroundCollision(context))
        {
            return;
        }

        if(context.input_command.attack) 
        {
            context.TransitionToState(.Attack);
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
        // Prioritize transitioning into an attack over landing
        if(TriggerEndOfAttackTransition(context))
        {
            return;
        }

        // Landing action will only happen if the character hasn't trigger other actions
        if(HandleGroundCollision(context))
        {
            return;
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

        common.flip_to_face_opponent(context.physics_component);
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

pub const GuardReaction = struct 
{
    pub fn OnStart(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("GuardReaction.OnStart()\n", .{});

        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void
    {
        _ = context;
        std.debug.print("GuardReaction.OnEnd()\n", .{});
    }
};