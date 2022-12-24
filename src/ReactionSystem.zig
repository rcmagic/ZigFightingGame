const std = @import("std");
const CharacterData = @import("CharacterData.zig");
const Component = @import("Component.zig");
const GameState = @import("GameState.zig").GameState;
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const common = @import("common.zig");

pub const ReactionSystem = struct 
{
    pub fn init(allocator: std.mem.Allocator) !ReactionSystem
    {   _ = allocator;
        return ReactionSystem{};
    }

    pub fn Execute(self: *ReactionSystem, gameState: *GameState) !void
    {
        _ = self;

        for(gameState.reaction_components) | *component, entityIndex |
        {
            if(component.hitStop > 0)
            {
                component.hitStop -= 1;
            }
            else if(component.hitStun > 0)
            {
                component.hitStun -= 1;

                if(component.hitStun <= 0)
                {
                    var defenderState = &gameState.state_machine_components[entityIndex];
                    CommonStates.CommonToIdleTransitions(&defenderState.context);
                }
            }
            else if(component.guardStun > 0)
            {
                component.guardStun -= 1;

                if(component.guardStun <= 0)
                {
                    var defenderState = &gameState.state_machine_components[entityIndex];
                    CommonStates.CommonToIdleTransitions(&defenderState.context);
                }
            }
        }

        // Transition to reactions for all characters that were hit.
        for(gameState.hitEvents.items) | hitEvent |
        {
            var defenderState = &gameState.state_machine_components[hitEvent.defenderID];

            const input = gameState.inputComponents[hitEvent.defenderID].input_command;

            const defenderPhysics = gameState.physics_components[hitEvent.defenderID];
            const attackerPhysics = gameState.physics_components[hitEvent.attackerID];

            const AttackerOnLeftSide = attackerPhysics.position.x < defenderPhysics.position.x;            
            const WasGuarded = (AttackerOnLeftSide and input.right) or (!AttackerOnLeftSide and input.left);


            if(WasGuarded)
            {
                defenderState.context.TransitionToState(.GuardReaction);
                gameState.reaction_components[hitEvent.defenderID].guardStun = hitEvent.guardStun;
            }
            else
            {
                defenderState.context.TransitionToState(.Reaction);
                gameState.reaction_components[hitEvent.defenderID].hitStun = hitEvent.hitStun;
            }        

            gameState.reaction_components[hitEvent.defenderID].hitStop = hitEvent.hitStop;
            gameState.reaction_components[hitEvent.defenderID].knockBack = hitEvent.knockBack;

            gameState.reaction_components[hitEvent.attackerID].hitStop = hitEvent.hitStop;

            // Update non gameplay effecting statistics 
            gameState.stats_components[hitEvent.defenderID].totalHitStun = hitEvent.hitStun;
            gameState.stats_components[hitEvent.defenderID].totalGuardStun = hitEvent.guardStun;

        }

    }
};