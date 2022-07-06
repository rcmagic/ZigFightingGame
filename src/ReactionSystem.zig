const std = @import("std");
const CharacterData = @import("CharacterData.zig");
const Component = @import("Component.zig");
const GameState = @import("GameState.zig").GameState;
const StateMachine = @import("ActionStates/StateMachine.zig");

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
            if(component.hitStun > 0)
            {
                component.hitStun -= 1;

                if(component.hitStun <= 0)
                {
                    var defenderState = &gameState.stateMachineComponents[entityIndex];
                    defenderState.context.bTransition = true;
                    defenderState.context.NextState = StateMachine.CombatStateID.Standing;
                }
            }
        }

        // Transition to reactions for all characters that were hit.
        for(gameState.hitEvents.items) | hitEvent |
        {
            var defenderState = &gameState.stateMachineComponents[hitEvent.defenderID];
            defenderState.context.bTransition = true;
            defenderState.context.NextState = StateMachine.CombatStateID.Reaction;
            
            gameState.reactionComponents[hitEvent.defenderID].hitStun = hitEvent.hitStun;
        }

    }
};