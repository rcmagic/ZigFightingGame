const std = @import("std");
const math = @import("utils/math.zig");
const Component = @import("Component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const input = @import("input.zig");
const CharacterData = @import("CharacterData.zig");
const CollisionSystem = @import("CollisionSystem.zig").CollisionSystem;
const ReactionSystem = @import("ReactionSystem.zig").ReactionSystem;
const GameState = @import("GameState.zig").GameState;



// Handles moving all entities which have a physics component
fn PhysicsSystem(gameState: *GameState) !void 
{

    var entityIndex: usize = 0;
    while (entityIndex < gameState.entityCount) 
    {

        var component = &gameState.physics_components[entityIndex];

        // Check if the entity is facing its opponent
        {
            const opponent : usize = if(entityIndex == 0) 1 else 0;
            const opponentX = gameState.physics_components[opponent].position.x;

            component.facingOpponent =
                ( (opponentX < component.position.x) and component.facingLeft) or
                ( (opponentX > component.position.x) and !component.facingLeft);

        }
        const reactionComponent = &gameState.reactionComponents[entityIndex];
        // Only update physics when there is no hitstop
        if(reactionComponent.hitStop <= 0)
        {

            // move position based on the current velocity.
            component.position = component.position.Add(component.velocity);
            component.velocity = component.velocity.Add(component.acceleration);

            // Apply knockback
            if((reactionComponent.hitStun > 0 or reactionComponent.guardStun > 0) and reactionComponent.knockBack != 0)
            {        
                // Knock the entity back depending on which direction they are facing    
                if(component.facingLeft)
                {
                    component.position.x += reactionComponent.knockBack;
                }
                else 
                {
                    component.position.x -= reactionComponent.knockBack;
                }

                // Handle reducing knockback overtime
                const knockBackDeceleration : i32 = 1000;
                const knockbackThreshold : i32 = 1100;
                reactionComponent.knockBack -= knockBackDeceleration;

                if(std.math.absCast(reactionComponent.knockBack) < knockbackThreshold)
                {
                    reactionComponent.knockBack = 0;
                }
            }



        }
        entityIndex += 1;
    }
}

fn ActionSystem(gameState: *GameState) void 
{
    var entityIndex: usize = 0;
    while (entityIndex < gameState.entityCount) {
        const component = &gameState.stateMachineComponents[entityIndex];
        
        if( gameState.gameData) | gameData |
        {
            component.stateMachine.UpdateStateMachine(&component.context, gameData.Characters.items[entityIndex], gameData.ActionMaps.items[entityIndex]);
        }

        entityIndex += 1;
    }
}


fn InputCommandSystem(gameState: *GameState) void 
{
    gameState.stateMachineComponents[0].context.input_command = gameState.inputComponents[0].input_command;
    gameState.stateMachineComponents[1].context.input_command = gameState.inputComponents[1].input_command;
}

test "Test setting up game data" 
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();
    var gameData = GameState.InitializeGameData(Allocator);

    var Character1 = try CharacterData.CharacterProperties.init(Allocator);
    var Character2 = try CharacterData.CharacterProperties.init(Allocator);

    // Add a test character
    try gameData.Characters.append(Character1);
    try gameData.Characters.append(Character2);

    try std.testing.expect(gameData.Characters.items.len == 2);
}


test "Test adding an action to a character" 
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();
    var gameData = GameState.InitializeGameData(Allocator);

    var Character = try CharacterData.CharacterProperties.init(Allocator);
    try gameData.Characters.append(Character);

    var Action = try CharacterData.ActionProperties.init(Allocator);

    try gameData.Characters.items[0].Actions.append(Action);

    try std.testing.expect(gameData.Characters.items[0].Actions.items.len == 1);
}

test "Test adding an action with hitboxes to a character" 
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();
    var gameData = GameState.InitializeGameData(Allocator);

    var Character = try CharacterData.CharacterProperties.init(Allocator);
    try gameData.Characters.append(Character);

    var Action = try CharacterData.ActionProperties.init(Allocator);

    try gameData.Characters.items[0].Actions.append(Action);

    var HitboxGroup = try CharacterData.HitboxGroup.init(Allocator);

    try gameData.Characters.items[0].Actions.items[0].VulnerableHitboxGroups.append(HitboxGroup);

    try std.testing.expect(gameData.Characters.items[0].Actions.items[0].VulnerableHitboxGroups.items.len == 1);

    try gameData.Characters.items[0].Actions.items[0].VulnerableHitboxGroups.items[0].Hitboxes.append(CharacterData.Hitbox{});
    try gameData.Characters.items[0].Actions.items[0].VulnerableHitboxGroups.items[0].Hitboxes.append(CharacterData.Hitbox{});

    try std.testing.expect(gameData.Characters.items[0].Actions.items[0].VulnerableHitboxGroups.items[0].Hitboxes.items.len == 2);
}



pub fn UpdateGame(gameState: *GameState) !void {
    InputCommandSystem(gameState);
    try PhysicsSystem(gameState);
    try gameState.collisionSystem.Execute(gameState);
    try gameState.reactionSystem.Execute(gameState);
    ActionSystem(gameState);
    gameState.frameCount += 1;
}
