const std = @import("std");
const Component = @import("Component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const Input = @import("Input.zig");
const CharacterData = @import("CharacterData.zig");
const CollisionSystem = @import("CollisionSystem.zig").CollisionSystem;
const ReactionSystem = @import("ReactionSystem.zig").ReactionSystem;

pub const GameData = struct {
    Characters: std.ArrayList(CharacterData.CharacterProperties),     
    ActionMaps: std.ArrayList(std.StringHashMap(usize)), 
    ImageSequences: std.ArrayList(std.ArrayList(CharacterData.SequenceTexRef)),
    ImageSequenceMap: std.ArrayList(std.StringHashMap(usize)),


    pub fn FindSequenceTextures(self: *const GameData, characterIndex: usize, SequenceName: []const u8) ?*CharacterData.SequenceTexRef
    {
        if(self.ImageSequenceMap.items[characterIndex].get(SequenceName)) | index |
        {
            return &self.ImageSequences.items[characterIndex].items[index];            
        }
        return null;
    }
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

pub fn InitializeGameData(allocator: std.mem.Allocator) !GameData
{
    var gameData = GameData { 
        .Characters = std.ArrayList(CharacterData.CharacterProperties).init(allocator),
        .ActionMaps = std.ArrayList(std.StringHashMap(usize)).init(allocator),
        .ImageSequences = std.ArrayList(std.ArrayList(CharacterData.SequenceTexRef)).init(allocator),
        .ImageSequenceMap = std.ArrayList(std.StringHashMap(usize)).init(allocator)        
    };

    var data1 = try CharacterData.LoadAsset("assets/test_chara_1.json", allocator);
    var data2 = try CharacterData.LoadAsset("assets/test_chara_1.json", allocator);

    if(data1) | loadedData |
    {
        try gameData.Characters.append(loadedData);
        try gameData.ImageSequences.append(try CharacterData.LoadSequenceImages(loadedData, allocator));

        try gameData.ActionMaps.append(try CharacterData.GenerateActionNameMap(loadedData, allocator));
        // Create a hash map that lets us reference textures with a sequence name and index
        try gameData.ImageSequenceMap.append(try CharacterData.GenerateImageSequenceMap(loadedData, allocator));
        
    }

    if(data2) | loadedData |
    {
        try gameData.Characters.append(loadedData);
        try gameData.ImageSequences.append(try CharacterData.LoadSequenceImages(loadedData, allocator));

        try gameData.ActionMaps.append(try CharacterData.GenerateActionNameMap(loadedData, allocator));
        // Create a hash map that lets us reference textures with a sequence name and index
        try gameData.ImageSequenceMap.append(try CharacterData.GenerateImageSequenceMap(loadedData, allocator));
        
    }

    return gameData;
}


// For now our only test state is a global constant. Need to move this to somewhere where character
// specific data is stored.
var StandingCallbacks = StateMachine.CombatStateCallbacks{ .Name = "Standing",  .OnUpdate = CommonStates.Standing.OnUpdate, .OnStart = CommonStates.Standing.OnStart, .OnEnd = CommonStates.Standing.OnEnd };
var WalkingForwardCallbacks = StateMachine.CombatStateCallbacks{ .Name = "WalkingForward", .OnUpdate = CommonStates.WalkingForward.OnUpdate, .OnStart = CommonStates.WalkingForward.OnStart, .OnEnd = CommonStates.WalkingForward.OnEnd };
var WalkingBackwardCallbacks = StateMachine.CombatStateCallbacks{ .Name = "WalkingBackward", .OnUpdate = CommonStates.WalkingBackward.OnUpdate, .OnStart = CommonStates.WalkingBackward.OnStart, .OnEnd = CommonStates.WalkingBackward.OnEnd };
var JumpCallbacks = StateMachine.CombatStateCallbacks{ .Name = "Jump", .OnUpdate = CommonStates.Jump.OnUpdate, .OnStart = CommonStates.Jump.OnStart, .OnEnd = CommonStates.Jump.OnEnd };
var AttackCallbacks = StateMachine.CombatStateCallbacks{ .Name = "Attack",  .OnUpdate = CommonStates.Attack.OnUpdate, .OnStart = CommonStates.Attack.OnStart, .OnEnd = CommonStates.Attack.OnEnd };
var ReactionCallbacks = StateMachine.CombatStateCallbacks{ .Name = "Reaction",  .OnUpdate = CommonStates.Reaction.OnUpdate, .OnStart = CommonStates.Reaction.OnStart, .OnEnd = CommonStates.Reaction.OnEnd };

// Register states for our character
fn RegisterActionStates(registery: *StateMachine.CombatStateRegistery) void
{
    registery.RegisterCommonState(StateMachine.CombatStateID.Standing, &StandingCallbacks);
    registery.RegisterCommonState(StateMachine.CombatStateID.WalkingForward, &WalkingForwardCallbacks);
    registery.RegisterCommonState(StateMachine.CombatStateID.WalkingBackward, &WalkingBackwardCallbacks);
    registery.RegisterCommonState(StateMachine.CombatStateID.Jump, &JumpCallbacks);
    registery.RegisterCommonState(StateMachine.CombatStateID.Attack, &AttackCallbacks);
    registery.RegisterCommonState(StateMachine.CombatStateID.Reaction, &ReactionCallbacks);
}



pub const HitEvent = struct {
    attackerID: usize,
    defenderID: usize,
    hitStun: i32,
    hitStop: i32,
    knockBack: i32,
};



pub const GameState = struct {
    frameCount: i32 = 0,
    entityCount: usize = 0,
    physicsComponents: [10]Component.PhysicsComponent = [_]Component.PhysicsComponent{.{}} ** 10,
    stateMachineComponents: [10]StateMachineComponent = [_]StateMachineComponent{.{}} ** 10,
    timelineComponents: [10]Component.TimelineComponent = [_]Component.TimelineComponent{.{}} ** 10,
    reactionComponents: [10]Component.ReactionComponent = [_]Component.ReactionComponent{.{}} ** 10,
    inputComponents: [2]InputComponent = [_]InputComponent{.{}} ** 2,

    // Transient Events
    hitEvents: std.ArrayList(HitEvent),

    // Systems
    collisionSystem: CollisionSystem,

    reactionSystem: ReactionSystem,

    allocator: std.mem.Allocator,
    gameData: ?GameData = null,


    // Boilerplate for setting up the components and state machine for one character.
    fn CreateAndInitOneCharacter(self: *GameState) void
    {
        // Setup referenced components used by the action state machine for a character.
        self.stateMachineComponents[self.entityCount].context.PhysicsComponent = &self.physicsComponents[self.entityCount];
        self.stateMachineComponents[self.entityCount].context.TimelineComponent = &self.timelineComponents[self.entityCount];
        self.stateMachineComponents[self.entityCount].context.ReactionComponent = &self.reactionComponents[self.entityCount];

        // Register states
        RegisterActionStates(&self.stateMachineComponents[self.entityCount].stateMachine.Registery);

        self.entityCount += 1;
    }

    pub fn init(self: *GameState, allocator: std.mem.Allocator) !void 
    {
        
        self.* = GameState {
            .allocator = allocator,
            
            // Game data initialization
            .gameData = try InitializeGameData(allocator),

            // Initialize Systems
            .collisionSystem = try CollisionSystem.init(allocator),

            .reactionSystem = try ReactionSystem.init(allocator),

            // Initialize the hit event
            // TODO: Make the number of max hit events a configurable property?
            .hitEvents = try std.ArrayList(HitEvent).initCapacity(allocator, 10)
        };

        // For now we are only creating two characters to work with.
        self.CreateAndInitOneCharacter();
        self.CreateAndInitOneCharacter();
    }
};
