const std = @import("std");
const component = @import("component.zig");
const StateMachine = @import("ActionStates/StateMachine.zig");
const CommonStates = @import("ActionStates/CommonStates.zig");
const input = @import("input.zig");
const character_data = @import("character_data.zig");
const collision_system = @import("collision_system.zig").CollisionSystem;
const reaction_system = @import("reaction_system.zig").reaction_system;
const asset = @import("asset.zig");

var StorageAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub var AssetStorage = asset.Storage.init(StorageAllocator.allocator());

pub var ActionMaps: std.ArrayList(std.StringHashMap(*const character_data.ActionProperties)) = std.ArrayList(std.StringHashMap(*const character_data.ActionProperties)).init(StorageAllocator.allocator());

pub const GameData = struct {
    CharacterAssets: std.ArrayList(*character_data.CharacterProperties),
    image_sequences: std.ArrayList(std.ArrayList(character_data.SequenceTexRef)),
    ImageSequenceMap: std.ArrayList(std.StringHashMap(usize)),

    pub fn findSequenceTextures(self: *const GameData, characterIndex: usize, SequenceName: []const u8) ?*character_data.SequenceTexRef {
        if (self.ImageSequenceMap.items[characterIndex].get(SequenceName)) |index| {
            return &self.image_sequences.items[characterIndex].items[index];
        }
        return null;
    }

    fn LoadOneCharacter(self: *GameData, path: [:0]const u8, allocator: std.mem.Allocator) !void {
        try AssetStorage.loadAsset(character_data.CharacterProperties, path);

        const characterAsset: asset.AssetInfo = AssetStorage.getAsset(path);

        switch (characterAsset.type) {
            .Character => |character| {
                try self.CharacterAssets.append(character);
                try self.image_sequences.append(try character_data.loadSequenceImages(character.*, allocator));

                try ActionMaps.append(try character_data.generateActionNameMap(character, allocator));
                // Create a hash map that lets us reference textures with a sequence name and index
                try self.ImageSequenceMap.append(try character_data.generateImageSequenceMap(character.*, allocator));
            },
            else => @panic("Character Data Failed to Load"),
        }
    }
};

const StateMachineComponent = struct { context: StateMachine.CombatStateContext = .{}, stateMachine: StateMachine.CombatStateMachineProcessor = .{} };

pub fn InitializeGameData(allocator: std.mem.Allocator) !GameData {
    var gameData = GameData{
        .CharacterAssets = std.ArrayList(*character_data.CharacterProperties).init(allocator),
        .image_sequences = std.ArrayList(std.ArrayList(character_data.SequenceTexRef)).init(allocator),
        .ImageSequenceMap = std.ArrayList(std.StringHashMap(usize)).init(allocator),
    };

    try gameData.LoadOneCharacter("assets/test_chara_1.json", allocator);
    try gameData.LoadOneCharacter("assets/test_chara_1.json", allocator);

    return gameData;
}

// Register states for our character
fn RegisterActionStates(registery: *StateMachine.CombatStateRegistery) void {
    registery.RegisterCommonState(.Standing, CommonStates.Standing);
    registery.RegisterCommonState(.WalkingForward, CommonStates.WalkingForward);
    registery.RegisterCommonState(.WalkingBackward, CommonStates.WalkingBackward);
    registery.RegisterCommonState(.Jump, CommonStates.Jump);
    registery.RegisterCommonState(.Attack, CommonStates.Attack);
    registery.RegisterCommonState(.Special, CommonStates.Special);
    registery.RegisterCommonState(.Reaction, CommonStates.Reaction);
    registery.RegisterCommonState(.LaunchReaction, CommonStates.LaunchReaction);
    registery.RegisterCommonState(.GuardReaction, CommonStates.GuardReaction);
    registery.RegisterCommonState(.GrabReaction, CommonStates.GrabReaction);
}

pub const HitEvent = struct {
    hitProperty: character_data.HitProperty,
    attackerID: usize,
    defenderID: usize,
};

const MAX_ENTITIES = 10;

pub const GameState = struct {
    frameCount: i32 = 0,
    entityCount: usize = 0,
    input_components: [MAX_ENTITIES]component.InputComponent = [_]component.InputComponent{.{}} ** MAX_ENTITIES,
    physics_components: [MAX_ENTITIES]component.PhysicsComponent = [_]component.PhysicsComponent{.{}} ** MAX_ENTITIES,
    state_machine_components: [MAX_ENTITIES]StateMachineComponent = [_]StateMachineComponent{.{}} ** MAX_ENTITIES,
    timeline_components: [MAX_ENTITIES]component.TimelineComponent = [_]component.TimelineComponent{.{}} ** MAX_ENTITIES,
    reaction_components: [MAX_ENTITIES]component.ReactionComponent = [_]component.ReactionComponent{.{}} ** MAX_ENTITIES,
    action_flags_components: [MAX_ENTITIES]component.ActionFlagsComponent = [_]component.ActionFlagsComponent{.{}} ** MAX_ENTITIES,
    stats_components: [MAX_ENTITIES]component.StatsComponent = [_]component.StatsComponent{.{}} ** MAX_ENTITIES,

    // Transient Events
    hitEvents: std.ArrayList(HitEvent),

    // Systems
    collisionSystem: collision_system,

    reactionSystem: reaction_system,

    gameData: ?GameData = null,

    // Boilerplate for setting up the components and state machine for one character.
    fn CreateAndInitOneCharacter(self: *GameState) void {
        // Setup referenced components used by the action state machine for a character.
        self.state_machine_components[self.entityCount].context.input_component = &self.input_components[self.entityCount];
        self.state_machine_components[self.entityCount].context.physics_component = &self.physics_components[self.entityCount];
        self.state_machine_components[self.entityCount].context.timeline_component = &self.timeline_components[self.entityCount];
        self.state_machine_components[self.entityCount].context.reaction_component = &self.reaction_components[self.entityCount];
        self.state_machine_components[self.entityCount].context.action_flags_component = &self.action_flags_components[self.entityCount];

        // Register states
        RegisterActionStates(&self.state_machine_components[self.entityCount].stateMachine.Registery);

        self.state_machine_components[self.entityCount].context.TransitionToState(.Standing);
        self.entityCount += 1;
    }

    // Load data from assets that will not be changed during runtime
    pub fn LoadPersistentGameAssets(self: *GameState, allocator: std.mem.Allocator) !void {
        self.gameData = try InitializeGameData(allocator);
    }

    // Load data that may change during runtime.
    pub fn init(self: *GameState, allocator: std.mem.Allocator) !void {
        self.* = GameState{

            // Initialize Systems
            .collisionSystem = try collision_system.init(allocator),

            .reactionSystem = try reaction_system.init(allocator),

            // Initialize the hit event
            // TODO: Make the number of max hit events a configurable property?
            .hitEvents = try std.ArrayList(HitEvent).initCapacity(allocator, 10),
        };

        // For now we are only creating two characters to work with.
        self.CreateAndInitOneCharacter();
        self.CreateAndInitOneCharacter();
    }
};
