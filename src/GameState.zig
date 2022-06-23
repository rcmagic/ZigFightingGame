const std = @import("std");
const Component = @import("Component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const Input = @import("Input.zig");
const CharacterData = @import("CharacterData.zig");

pub const GameData = struct {
    Characters: std.ArrayList(CharacterData.CharacterProperties), 
};


const StateMachineComponent = struct 
{ 
    context: StateMachine.CombatStateContext = .{},
    stateMachine: StateMachine.CombatStateMachineProcessor = .{}
};

const InputComponent = struct 
{ 
    inputCommand: Input.InputCommand = .{} 
};

pub fn InitializeGameData(allocator: std.mem.Allocator) GameData
{
    var gameData = GameData { 
        .Characters = std.ArrayList(CharacterData.CharacterProperties).init(allocator) 
    };

    //gameData.HitboxGroup.Hitboxes.append(CharacterData.Hitbox{ .top = 200, .left = 300, .bottom = 0, .right = 600 }) catch unreachable;

    return gameData;
}


// For now our only test state is a global constant. Need to move this to somewhere where character
// specific data is stored.
var StandingCallbacks = StateMachine.CombatStateCallbacks{ .Name = "Standing",  .OnUpdate = CommonStates.Standing.OnUpdate, .OnStart = CommonStates.Standing.OnStart, .OnEnd = CommonStates.Standing.OnEnd };
var WalkingForwardCallbacks = StateMachine.CombatStateCallbacks{ .Name = "WalkingForward", .OnUpdate = CommonStates.WalkingForward.OnUpdate, .OnStart = CommonStates.WalkingForward.OnStart, .OnEnd = CommonStates.WalkingForward.OnEnd };



pub const GameState = struct {
    frameCount: i32 = 0,
    entityCount: i32 = 1,
    physicsComponents: [10]Component.PhysicsComponent = [_]Component.PhysicsComponent{.{}} ** 10,
    stateMachineComponents: [10]StateMachineComponent = [_]StateMachineComponent{.{}} ** 10,

    inputComponents: [2]InputComponent = [_]InputComponent{.{}} ** 2,

    // Systems
    //collisionSystem: CollisionSystem,

    allocator: std.mem.Allocator,
    gameData: ?GameData = null,

    pub fn init(allocator: std.mem.Allocator) !GameState 
    {
        var state = GameState {
            .allocator = allocator,
            
            // Game data initialization
            .gameData = InitializeGameData(allocator),

            // Initialize Systems
            //.collisionSystem = CollisionSystem.init(allocator)
        };

        state.stateMachineComponents[0].context.PhysicsComponent = &state.physicsComponents[0];
        
        // testing initializing a single entity
        state.stateMachineComponents[0].stateMachine.Context = &state.stateMachineComponents[0].context;
        state.stateMachineComponents[0].stateMachine.Registery.RegisterCommonState(StateMachine.CombatStateID.Standing, &StandingCallbacks);
        state.stateMachineComponents[0].stateMachine.Registery.RegisterCommonState(StateMachine.CombatStateID.WalkingForward, &WalkingForwardCallbacks);


        return state;
    }
};
