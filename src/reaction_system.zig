const std = @import("std");
const character_data = @import("character_data.zig");
const component = @import("component.zig");
const GameState = @import("GameState.zig").GameState;
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const common = @import("common.zig");

pub const reaction_system = struct {
    pub fn init(allocator: std.mem.Allocator) !reaction_system {
        _ = allocator;
        return reaction_system{};
    }

    pub fn execute(self: *reaction_system, gameState: *GameState) !void {
        _ = self;

        for (&gameState.reaction_components, 0..) |*reaction, entityIndex| {
            if (reaction.hitStop > 0) {
                reaction.hitStop -= 1;
            } else if (reaction.hitStun > 0) {
                reaction.hitStun -= 1;

                if (reaction.hitStun <= 0) {
                    var defenderState = &gameState.state_machine_components[entityIndex];
                    CommonStates.CommonToIdleTransitions(&defenderState.context);
                }
            } else if (reaction.guardStun > 0) {
                reaction.guardStun -= 1;

                if (reaction.guardStun <= 0) {
                    var defenderState = &gameState.state_machine_components[entityIndex];
                    CommonStates.CommonToIdleTransitions(&defenderState.context);
                }
            }
        }

        // Transition to reactions for all characters that were hit.
        for (gameState.hitEvents.items) |hitEvent| {
            var defenderState = &gameState.state_machine_components[hitEvent.defenderID];

            const input = gameState.input_components[hitEvent.defenderID].input_command;

            const defenderPhysics = gameState.physics_components[hitEvent.defenderID];
            const attackerPhysics = gameState.physics_components[hitEvent.attackerID];

            const AttackerOnLeftSide = attackerPhysics.position.x < defenderPhysics.position.x;
            const WasGuarded = (AttackerOnLeftSide and input.right) or (!AttackerOnLeftSide and input.left);

            if (hitEvent.hitProperty.isGrab) {
                if ((attackerPhysics.position.y > 0 and defenderPhysics.position.y > 0) or
                    (attackerPhysics.position.y == 0 and defenderPhysics.position.y == 0))
                {
                    defenderState.context.TransitionToState(.GrabReaction);
                    defenderState.context.reaction_component.grabLocked = true;
                }
            } else if (WasGuarded) {
                defenderState.context.TransitionToState(.GuardReaction);
                gameState.reaction_components[hitEvent.defenderID].guardStun = hitEvent.hitProperty.guardStun;
            } else {
                if (hitEvent.hitProperty.isLaunch) {
                    gameState.reaction_components[hitEvent.defenderID].airKnockback = hitEvent.hitProperty.airKnockback;
                    gameState.reaction_components[hitEvent.defenderID].launchVelocityY = hitEvent.hitProperty.launchVelocityY;
                    defenderState.context.TransitionToState(.LaunchReaction);
                } else {
                    // Only ground knockback physics for grounded attacks.
                    gameState.reaction_components[hitEvent.defenderID].knockBack = hitEvent.hitProperty.knockBack;
                    defenderState.context.TransitionToState(.Reaction);
                }

                gameState.reaction_components[hitEvent.defenderID].hitStun = hitEvent.hitProperty.hitStun;
            }

            gameState.reaction_components[hitEvent.defenderID].hitStop = hitEvent.hitProperty.hitStop;

            gameState.reaction_components[hitEvent.attackerID].hitStop = hitEvent.hitProperty.hitStop;

            // Update non gameplay effecting statistics
            gameState.stats_components[hitEvent.defenderID].totalHitStun = hitEvent.hitProperty.hitStun;
            gameState.stats_components[hitEvent.defenderID].totalGuardStun = hitEvent.hitProperty.guardStun;
        }
    }
};
