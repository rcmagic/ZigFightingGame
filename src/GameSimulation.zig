const std = @import("std");
const math = @import("utils/math.zig");
const Component = @import("Component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const Input = @import("Input.zig");
const CharacterData = @import("CharacterData.zig");
const CollisionSystem = @import("CollisionSystem.zig");

const InputComponent = struct { inputCommand: Input.InputCommand = .{} };

const StateMachineComponent = struct { context: StateMachine.CombatStateContext = .{}, stateMachine: StateMachine.CombatStateMachineProcessor = .{} };

// For now our only test state is a global constant. Need to move this to somewhere where character
// specific data is stored.
var StandingCallbacks = StateMachine.CombatStateCallbacks{ .OnUpdate = CommonStates.Standing.OnUpdate, .OnStart = CommonStates.Standing.OnStart, .OnEnd = CommonStates.Standing.OnEnd };

var WalkingForwardCallbacks = StateMachine.CombatStateCallbacks{ .OnUpdate = CommonStates.WalkingForward.OnUpdate, .OnStart = CommonStates.WalkingForward.OnStart, .OnEnd = CommonStates.WalkingForward.OnEnd };



pub const GameData = struct {
    HitboxGroup: CharacterData.HitboxGroup,
    
    //CharacterProperties: [10]CharacterData.CharacterProperties
};

pub fn InitializeGameData(allocator: std.mem.Allocator) GameData
{
    var gameData = GameData{ .HitboxGroup = .{ .Hitboxes = std.ArrayList(CharacterData.Hitbox).init(allocator) } };

    gameData.HitboxGroup.Hitboxes.append(CharacterData.Hitbox{ .top = 200, .left = 300, .bottom = 0, .right = 600 }) catch unreachable;

    return gameData;
}


pub const GameState = struct {
    frameCount: i32 = 0,
    entityCount: i32 = 1,
    physicsComponents: [10]Component.PhysicsComponent = [_]Component.PhysicsComponent{.{}} ** 10,
    stateMachineComponents: [10]StateMachineComponent = [_]StateMachineComponent{.{}} ** 10,

    inputComponents: [2]InputComponent = [_]InputComponent{.{}} ** 2,

    allocator: std.mem.Allocator,
    gameData: ?GameData = null,

    pub fn Init(self: *GameState) void 
    {
        // Game data initialization
        self.gameData = InitializeGameData(self.allocator);


        self.stateMachineComponents[0].context.PhysicsComponent = &self.physicsComponents[0];
       
        // testing initializing a single entity
        self.stateMachineComponents[0].stateMachine.Context = &self.stateMachineComponents[0].context;
        self.stateMachineComponents[0].stateMachine.Registery.RegisterCommonState(StateMachine.CombatStateID.Standing, &StandingCallbacks);
        self.stateMachineComponents[0].stateMachine.Registery.RegisterCommonState(StateMachine.CombatStateID.WalkingForward, &WalkingForwardCallbacks);


    }
};

// Handles moving all entities which have a physics component
fn PhysicsSystem(gameState: *GameState) void 
{
    var entityIndex: usize = 0;
    while (entityIndex < gameState.entityCount) 
    {
        const component = &gameState.physicsComponents[entityIndex];

        // move position based on the current velocity.
        component.position = component.position.Add(component.velocity);
        component.velocity = component.velocity.Add(component.acceleration);

        entityIndex += 1;
    }
}

fn ActionSystem(gameState: *GameState) void 
{
    var entityIndex: usize = 0;
    while (entityIndex < gameState.entityCount) {
        const component = &gameState.stateMachineComponents[entityIndex];

        component.stateMachine.UpdateStateMachine();

        entityIndex += 1;
    }
}


fn InputCommandSystem(gameState: *GameState) void 
{
    gameState.stateMachineComponents[0].context.InputCommand = gameState.inputComponents[0].inputCommand;
}

test "Testing setting up game data" 
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();
    var gameData = GameData{ .HitboxGroup = .{ .Hitboxes = std.ArrayList(CharacterData.Hitbox).init(Allocator) } };

    try gameData.HitboxGroup.Hitboxes.append(CharacterData.Hitbox{ .top = 200, .left = -300, .bottom = 0, .right = 300 });
    try std.testing.expect(gameData.HitboxGroup.Hitboxes.items[0].right == 300);
}

pub fn UpdateGame(gameState: *GameState) void {
    InputCommandSystem(gameState);
    ActionSystem(gameState);
    PhysicsSystem(gameState);
    gameState.frameCount += 1;
}
