const std = @import("std");
const math = @import("utils/math.zig");
const component = @import("component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const input = @import("input.zig");
const character_data = @import("character_data.zig");
const collision_system = @import("collision_system.zig").CollisionSystem;
const reaction_system = @import("reaction_system.zig").reaction_system;
const GameState = @import("GameState.zig").GameState;



// Handles moving all entities which have a physics component
fn physicsSystem(gameState: *GameState) !void 
{

    var entityIndex: usize = 0;
    while (entityIndex < gameState.entityCount) 
    {

        var physics = &gameState.physics_components[entityIndex];

        // Check if the entity is facing its opponent
        {
            const opponent : usize = if(entityIndex == 0) 1 else 0;
            const opponentX = gameState.physics_components[opponent].position.x;

            physics.facingOpponent =
                ( (opponentX < physics.position.x) and physics.facingLeft) or
                ( (opponentX > physics.position.x) and !physics.facingLeft);

        }
        const reactionComponent = &gameState.reaction_components[entityIndex];
        // Only update physics when there is no hitstop
        if(reactionComponent.hitStop <= 0)
        {

            // move position based on the current velocity.
            physics.position = physics.position.Add(physics.velocity);
            physics.velocity = physics.velocity.Add(physics.acceleration);

            // Apply knockback
            if((reactionComponent.hitStun > 0 or reactionComponent.guardStun > 0) and reactionComponent.knockBack != 0)
            {        
                // Knock the entity back depending on which direction they are facing    
                if(physics.facingLeft)
                {
                    physics.position.x += reactionComponent.knockBack;
                }
                else 
                {
                    physics.position.x -= reactionComponent.knockBack;
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

fn actionSystem(gameState: *GameState) void 
{
    var entityIndex: usize = 0;
    while (entityIndex < gameState.entityCount) {
        const state_machine = &gameState.state_machine_components[entityIndex];
        
        if( gameState.gameData) | gameData |
        {
            state_machine.stateMachine.UpdateStateMachine(&state_machine.context, gameData.Characters.items[entityIndex], gameData.ActionMaps.items[entityIndex]);
        }

        entityIndex += 1;
    }
}


fn inputCommandSystem(gameState: *GameState) void 
{
    gameState.state_machine_components[0].context.input_command = gameState.input_components[0].input_command;
    gameState.state_machine_components[1].context.input_command = gameState.input_components[1].input_command;
}

test "Test setting up game data" 
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();
    var gameData = GameState.InitializeGameData(Allocator);

    var Character1 = try character_data.CharacterProperties.init(Allocator);
    var Character2 = try character_data.CharacterProperties.init(Allocator);

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

    var Character = try character_data.CharacterProperties.init(Allocator);
    try gameData.Characters.append(Character);

    var Action = try character_data.actionsProperties.init(Allocator);

    try gameData.Characters.items[0].actions.append(Action);

    try std.testing.expect(gameData.Characters.items[0].actions.items.len == 1);
}

test "Test adding an action with hitboxes to a character" 
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();
    var gameData = GameState.InitializeGameData(Allocator);

    var Character = try character_data.CharacterProperties.init(Allocator);
    try gameData.Characters.append(Character);

    var Action = try character_data.actionsProperties.init(Allocator);

    try gameData.Characters.items[0].actions.append(Action);

    var HitboxGroup = try character_data.HitboxGroup.init(Allocator);

    try gameData.Characters.items[0].actions.items[0].vulnerable_hitbox_groups.append(HitboxGroup);

    try std.testing.expect(gameData.Characters.items[0].actions.items[0].vulnerable_hitbox_groups.items.len == 1);

    try gameData.Characters.items[0].actions.items[0].vulnerable_hitbox_groups.items[0].hitboxes.append(character_data.Hitbox{});
    try gameData.Characters.items[0].actions.items[0].vulnerable_hitbox_groups.items[0].hitboxes.append(character_data.Hitbox{});

    try std.testing.expect(gameData.Characters.items[0].actions.items[0].vulnerable_hitbox_groups.items[0].hitboxes.items.len == 2);
}



pub fn updateGame(gameState: *GameState) !void {
    inputCommandSystem(gameState);
    try physicsSystem(gameState);
    actionSystem(gameState);
    try gameState.collisionSystem.execute(gameState);
    try gameState.reactionSystem.execute(gameState);
    gameState.frameCount += 1;
}
