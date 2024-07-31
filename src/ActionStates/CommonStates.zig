const std = @import("std");
const StateMachine = @import("StateMachine.zig");
const component = @import("../component.zig");
const common = @import("../common.zig");
const input = @import("../input.zig");
const asset = @import("../asset.zig");
const GameState = @import("../GameState.zig");

// When the character collides with the ground, return to ground states.
fn HandleGroundCollision(context: *StateMachine.CombatStateContext) bool {
    if (context.physics_component.velocity.y < 0 and context.physics_component.position.y <= 0) {
        context.physics_component.position.y = 0;
        context.physics_component.velocity.y = 0;
        context.physics_component.acceleration.y = 0;

        common.flip_to_face_opponent(context.physics_component);
        context.TransitionToState(.Standing);

        return true;
    }

    return false;
}

fn CommonJumpTransitions(context: *StateMachine.CombatStateContext) bool {
    if (context.input_component.IsInputHeld(.Up, context.physics_component.facingLeft)) {
        context.action_flags_component.jumpFlags = .None;

        if (context.input_component.IsInputHeld(.Forward, context.physics_component.facingLeft)) {
            context.action_flags_component.jumpFlags = .JumpForward;
        } else if (context.input_component.IsInputHeld(.Back, context.physics_component.facingLeft)) {
            context.action_flags_component.jumpFlags = .JumpBack;
        }

        context.TransitionToState(.Jump);

        return true;
    }

    return false;
}

fn CommonAttackTransitions(context: *StateMachine.CombatStateContext) bool {

    // Go through all the character asset specified actions first and check their inputs.
    const character = context.character_asset;

    for (character.action_inputs.items) |action_input| {
        switch (action_input.action.type) {
            .Action => {
                if (action_input.action.type.Action.combat_state == .Attack) {
                    if (context.input_component.WasInputPressed(
                        action_input.button,
                        context.physics_component.facingLeft,
                    ) and
                        context.input_component.WasMotionExecuted(
                        action_input.motion,
                        30,
                        context.physics_component.facingLeft,
                    )) {
                        context.TransitionToStateRef(action_input.action.type.Action);
                        return true;
                    }
                }
            },
            else => {},
        }
    }

    if (context.input_component.WasInputPressed(
        input.InputNames.Attack,
        context.physics_component.facingLeft,
    ) and
        context.input_component.WasMotionExecuted(
        input.MotionNames.QCF,
        30,
        context.physics_component.facingLeft,
    )) {
        context.TransitionToState(.Special);
        return true;
    }

    if (context.input_component.WasInputPressed(
        input.InputNames.Attack,
        context.physics_component.facingLeft,
    )) {
        context.TransitionToState(.Attack);
        return true;
    }

    return false;
}

fn SpecialCancelTransitions(context: *StateMachine.CombatStateContext) bool {
    // Don't cancel during hitstop
    if (context.reaction_component.hitStop > 0) {
        return false;
    }

    // Can't special cancel when an attack hasn't hit.
    if (!context.reaction_component.attackHasHitForSpecialCancel) {
        return false;
    }

    // if(context.input_component.WasInputPressedBuffered(input.InputNames.Attack, 30, context.physics_component.facingLeft) and
    //     context.input_component.WasMotionExecuted(input.MotionNames.QCF, 30))
    // {
    //      context.TransitionToState(.Special);
    //      return true;
    // }

    if (context.input_component.WasInputPressedBuffered(
        input.InputNames.Attack,
        15,
        context.physics_component.facingLeft,
    )) {
        context.TransitionToState(.Special);
        return true;
    }

    return false;
}

fn CommonJumpAttackTransitions(context: *StateMachine.CombatStateContext) bool {
    return CommonAttackTransitions(context);
}

fn CommonTransitions(context: *StateMachine.CombatStateContext) bool {
    if (CommonAttackTransitions(context)) {
        return true;
    } else if (CommonJumpTransitions(context)) {
        return true;
    } else if (context.input_component.IsInputHeld(.Forward, context.physics_component.facingLeft)) {
        context.TransitionToState(.WalkingForward);
        return true;
    } else if (context.input_component.IsInputHeld(.Back, context.physics_component.facingLeft)) {
        context.TransitionToState(.WalkingBackward);
        return true;
    }

    return false;
}

pub fn CommonToIdleTransitions(context: *StateMachine.CombatStateContext) void {
    if (context.physics_component.position.y > 0) {
        if (CommonJumpAttackTransitions(context)) {
            return;
        }

        context.TransitionToState(.Jump);
    } else {
        if (CommonTransitions(context)) {
            return;
        }
        context.TransitionToState(.Standing);
    }

    // @todo. I don't think we need this, but need to check why this is here 2024/2/2
    context.bTransition = true;
}

fn TriggerEndOfAttackTransition(context: *StateMachine.CombatStateContext) bool {
    // Only check for idle action transitions on the final frame.
    if (context.timeline_component.framesElapsed >= context.ActionData.duration) {
        CommonToIdleTransitions(context);
        return true;
    }

    return false;
}

// Standing state
pub const Standing = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Standing.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        //  Stop character movement on standing.
        context.physics_component.velocity.x = 0;

        if (CommonTransitions(context)) {
            return;
        }

        // automatically turn the character to face the opponent when they've changed sides
        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Standing.OnEnd()\n", .{});
    }
};

pub const WalkingForward = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("WalkingForward.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        const WalkingForwardSpeed = 3000;
        context.physics_component.SetForwardSpeed(WalkingForwardSpeed);

        if (CommonAttackTransitions(context)) {
            return; // Bail out of this state when a transition has been detected
        } else if (CommonJumpTransitions(context)) {
            return; // Bail out of this state when a transition has been detected
        } else if (context.input_component.IsInputHeld(.Back, context.physics_component.facingLeft)) {
            context.TransitionToState(.WalkingBackward);
            return;
        }

        if (!context.input_component.IsInputHeld(.Forward, context.physics_component.facingLeft)) {
            context.TransitionToState(.Standing);
        }

        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("WalkingForward.OnEnd()\n", .{});
    }
};

pub const WalkingBackward = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("WalkingBackward.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        if (CommonAttackTransitions(context)) {
            return; // Bail out of this state when a transition has been detected
        } else if (CommonJumpTransitions(context)) {
            return; // Bail out of this state when a transition has been detected
        } else if (context.input_component.IsInputHeld(.Forward, context.physics_component.facingLeft)) {
            context.TransitionToState(.WalkingForward);
            return;
        }

        const WalkingBackSpeed = -2000;
        context.physics_component.SetForwardSpeed(WalkingBackSpeed);

        if (!context.input_component.IsInputHeld(.Back, context.physics_component.facingLeft)) {
            context.TransitionToState(.Standing);
        }

        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("WalkingBackward.OnEnd()\n", .{});
    }
};

pub const Jump = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        std.debug.print("Jump.OnStart()\n", .{});

        // Only initialize jump velocity when on the ground.
        if (context.physics_component.position.y <= 0) {
            context.physics_component.velocity.y = 20000;
        }

        context.physics_component.acceleration.y = -800;

        const ForwardSpeed: i32 = switch (context.action_flags_component.jumpFlags) {
            .None => 0,
            .JumpForward => 2500,
            .JumpBack => -1000,
        };

        context.physics_component.SetForwardSpeed(ForwardSpeed);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        if (HandleGroundCollision(context)) {
            return;
        }

        if (CommonAttackTransitions(context)) {
            return;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Jump.OnEnd()\n", .{});
    }
};

pub const Attack = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Attack.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        // Prioritize transitioning into an attack over landing
        if (TriggerEndOfAttackTransition(context)) {
            return;
        }

        // Landing action will only happen if the character hasn't trigger other actions
        if (HandleGroundCollision(context)) {
            return;
        }

        if (SpecialCancelTransitions(context)) {
            return;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Attack.OnEnd()\n", .{});
    }
};

pub const Special = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Special.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        // Prioritize transitioning into an attack over landing
        if (TriggerEndOfAttackTransition(context)) {
            return;
        }

        // Landing action will only happen if the character hasn't trigger other actions
        if (HandleGroundCollision(context)) {
            return;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Special.OnEnd()\n", .{});
    }
};

const Crouching = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Crouching.OnStart()\n", .{});
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Crouching.OnUpdate()\n", .{});
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Crouching.OnEnd()\n", .{});
    }
};

pub const Reaction = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        std.debug.print("Reaction.OnStart()\n", .{});

        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        _ = context;
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("Reaction.OnEnd()\n", .{});
    }
};

pub const LaunchReaction = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        std.debug.print("LaunchReaction.OnStart()\n", .{});

        common.flip_to_face_opponent(context.physics_component);

        // Only initialize jump velocity when on the ground.
        context.physics_component.velocity.y = context.reaction_component.launchVelocityY;

        context.physics_component.acceleration.y = -800;

        context.physics_component.SetForwardSpeed(-context.reaction_component.airKnockback);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        if (HandleGroundCollision(context)) {
            return;
        }
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("LaunchReaction.OnEnd()\n", .{});
    }
};

pub const GuardReaction = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        std.debug.print("GuardReaction.OnStart()\n", .{});

        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        _ = context;
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("GuardReaction.OnEnd()\n", .{});
    }
};

pub const GrabReaction = struct {
    pub fn OnStart(context: *StateMachine.CombatStateContext) void {
        std.debug.print("GrabReaction.OnStart()\n", .{});

        common.flip_to_face_opponent(context.physics_component);
    }

    pub fn OnUpdate(context: *StateMachine.CombatStateContext) void {
        _ = context;
    }

    pub fn OnEnd(context: *StateMachine.CombatStateContext) void {
        _ = context;
        std.debug.print("GrabReaction.OnEnd()\n", .{});
    }
};
