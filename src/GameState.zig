const std = @import("std");
const Component = @import("Component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const input = @import("input.zig");
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
    input_command: input.InputCommand = .{} 
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
var GuardReactionCallbacks = StateMachine.CombatStateCallbacks{ .Name = "GuardReaction",  .OnUpdate = CommonStates.GuardReaction.OnUpdate, .OnStart = CommonStates.GuardReaction.OnStart, .OnEnd = CommonStates.GuardReaction.OnEnd };

// Register states for our character
fn RegisterActionStates(registery: *StateMachine.CombatStateRegistery) void
{
    registery.RegisterCommonState(.Standing, &StandingCallbacks);
    registery.RegisterCommonState(.WalkingForward, &WalkingForwardCallbacks);
    registery.RegisterCommonState(.WalkingBackward, &WalkingBackwardCallbacks);
    registery.RegisterCommonState(.Jump, &JumpCallbacks);
    registery.RegisterCommonState(.Attack, &AttackCallbacks);
    registery.RegisterCommonState(.Reaction, &ReactionCallbacks);
    registery.RegisterCommonState(.GuardReaction, &GuardReactionCallbacks);

}



pub const HitEvent = struct {
    attackerID: usize,
    defenderID: usize,
    hitStun: i32,
    guardStun: i32,
    hitStop: i32,
    knockBack: i32,
};


const MAX_ENTITIES = 10;

pub const GameState = struct {
    frameCount: i32 = 0,
    entityCount: usize = 0,
    physics_components: [MAX_ENTITIES]Component.PhysicsComponent = [_]Component.PhysicsComponent{.{}} ** MAX_ENTITIES,
    stateMachineComponents: [MAX_ENTITIES]StateMachineComponent = [_]StateMachineComponent{.{}} ** MAX_ENTITIES,
    timelineComponents: [MAX_ENTITIES]Component.TimelineComponent = [_]Component.TimelineComponent{.{}} ** MAX_ENTITIES,
    reactionComponents: [MAX_ENTITIES]Component.ReactionComponent = [_]Component.ReactionComponent{.{}} ** MAX_ENTITIES,
    actionFlagsComponents: [MAX_ENTITIES]Component.ActionFlagsComponent = [_]Component.ActionFlagsComponent{.{}} ** MAX_ENTITIES,
    statsComponents: [MAX_ENTITIES]Component.StatsComponent = [_]Component.StatsComponent{.{}} ** MAX_ENTITIES,

    // "Global" components
    inputComponents: [2]InputComponent = [_]InputComponent{.{}} ** 2,

    // Transient Events
    hitEvents: std.ArrayList(HitEvent),

    // Systems
    collisionSystem: CollisionSystem,

    reactionSystem: ReactionSystem,

    gameData: ?GameData = null,


    // Boilerplate for setting up the components and state machine for one character.
    fn CreateAndInitOneCharacter(self: *GameState) void
    {
        // Setup referenced components used by the action state machine for a character.
        self.stateMachineComponents[self.entityCount].context.physics_component = &self.physics_components[self.entityCount];
        self.stateMachineComponents[self.entityCount].context.TimelineComponent = &self.timelineComponents[self.entityCount];
        self.stateMachineComponents[self.entityCount].context.ReactionComponent = &self.reactionComponents[self.entityCount];
        self.stateMachineComponents[self.entityCount].context.ActionFlagsComponent = &self.actionFlagsComponents[self.entityCount];

        // Register states
        RegisterActionStates(&self.stateMachineComponents[self.entityCount].stateMachine.Registery);

        self.entityCount += 1;
    }


    // Load data from assets that will not be changed during runtime
    pub fn LoadPersistentGameAssets(self: *GameState, allocator: std.mem.Allocator) !void
    {
        self.gameData = try InitializeGameData(allocator);
    }

    // Load data that may change during runtime. 
    pub fn init(self: *GameState, allocator: std.mem.Allocator) !void 
    {
        
        self.* = GameState {
                
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
