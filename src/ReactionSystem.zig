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

        for(gameState.reactionComponents) | *component, entityIndex |
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
                    var defenderState = &gameState.stateMachineComponents[entityIndex];
                    CommonStates.CommonToIdleTransitions(&defenderState.context);
                }
            }
            else if(component.guardStun > 0)
            {
                component.guardStun -= 1;

                if(component.guardStun <= 0)
                {
                    var defenderState = &gameState.stateMachineComponents[entityIndex];
                    CommonStates.CommonToIdleTransitions(&defenderState.context);
                }
            }
        }

        // Transition to reactions for all characters that were hit.
        for(gameState.hitEvents.items) | hitEvent |
        {
            var defenderState = &gameState.stateMachineComponents[hitEvent.defenderID];
            defenderState.context.bTransition = true;


            const input = gameState.inputComponents[hitEvent.defenderID].inputCommand;

            const defenderPhysics = gameState.physicsComponents[hitEvent.defenderID];
            const attackerPhysics = gameState.physicsComponents[hitEvent.attackerID];

            const AttackerOnLeftSide = attackerPhysics.position.x < defenderPhysics.position.x;            
            const WasGuarded = (AttackerOnLeftSide and input.Right) or (!AttackerOnLeftSide and input.Left);


            if(WasGuarded)
            {
                defenderState.context.NextState = StateMachine.CombatStateID.GuardReaction;
                gameState.reactionComponents[hitEvent.defenderID].guardStun = hitEvent.guardStun;

            }
            else
            {
                defenderState.context.NextState = StateMachine.CombatStateID.Reaction;
                gameState.reactionComponents[hitEvent.defenderID].hitStun = hitEvent.hitStun;
            }        

            gameState.reactionComponents[hitEvent.defenderID].hitStop = hitEvent.hitStop;
            gameState.reactionComponents[hitEvent.defenderID].knockBack = hitEvent.knockBack;

            gameState.reactionComponents[hitEvent.attackerID].hitStop = hitEvent.hitStop;

            // Update non gameplay effecting statistics 
            gameState.statsComponents[hitEvent.defenderID].totalHitStun = hitEvent.hitStun;
            gameState.statsComponents[hitEvent.defenderID].totalGuardStun = hitEvent.guardStun;

        }

    }
};