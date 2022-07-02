const std = @import("std");
const math = @import("utils/math.zig");
const CharacterData = @import("CharacterData.zig");
const Component = @import("Component.zig");
const GameState = @import("GameState.zig").GameState;


// Create a new hitbox translated by the offset provided.
fn TranslateHitbox(hitbox: CharacterData.Hitbox, offset: math.IntVector2D) CharacterData.Hitbox
{
    return CharacterData.Hitbox {   .left   =   (hitbox.left + offset.x), 
                                    .top    =   (hitbox.top + offset.y),
                                    .right  =   (hitbox.right + offset.x),
                                    .bottom =   (hitbox.bottom + offset.y)
    };
}

// Check to see if two hitboxes overlap 
fn DoHitboxesOverlap(a: CharacterData.Hitbox, b: CharacterData.Hitbox) bool
{
    const IsNotOverlapping = (a.left > b.right) 
                            or (b.left > a.right) 
                            or (a.bottom > b.top) 
                            or (b.bottom > a.top);
    return !IsNotOverlapping;                      
}

fn GetTranslatedActiveHitboxes(hitboxGroups: []const CharacterData.HitboxGroup, offset: math.IntVector2D, hitboxes: []CharacterData.Hitbox, framesElapsed: i32) usize
{
    var count: usize = 0;
    for(hitboxGroups) | hitboxGroup |
    {                
        if(hitboxGroup.IsActiveOnFrame(framesElapsed))
        {
            for(hitboxGroup.Hitboxes.items) | hitbox |
            {
                const translateBox = TranslateHitbox(hitbox, offset);                            

                hitboxes[count] = translateBox;
                count += 1;
            }
        }
    }

    return count;
}

const ScratchHitboxSet = struct
{
    hitboxStore: [10]CharacterData.Hitbox =  [_]CharacterData.Hitbox{.{}} ** 10,
    hitboxCount: usize = 0,
};



pub const CollisionSystem = struct 
{
    // Working memory to pass between the collision system stages
    VulnerableHitboxScratch: [100]CharacterData.Hitbox = [_]CharacterData.Hitbox{.{}} ** 100,
    AttackHitboxScratch: [100]CharacterData.Hitbox = [_]CharacterData.Hitbox{.{}} ** 100,

    VulnerableSlices : [10][]const CharacterData.Hitbox = undefined, 
    AttackSlices : [10][]const CharacterData.Hitbox = undefined,


    pub fn init(allocator: std.mem.Allocator) !CollisionSystem
    {   _ = allocator;
        return CollisionSystem{};
    }

    pub fn CollisionPhase(self: *CollisionSystem, gameState: *GameState) void
    {
        const activeAttackSlices = self.AttackSlices[0..gameState.entityCount];
        const activeVulnerableSlices = self.VulnerableSlices[0..gameState.entityCount];

        // Loop through all the active attacking entities's vulnerable boxes.
        for( activeAttackSlices ) | OneEntityAttackBoxes, attackerIndex |
        {                        
            for(OneEntityAttackBoxes) | attackBox |
            {                 
                // Loop through all the active defending entities's vulnerable boxes.
                for(activeVulnerableSlices) | OneEntityVulnerableBoxes, defenderIndex |
                {
                    // Don't check an attacker against itself.
                    if(attackerIndex == defenderIndex) 
                    {
                        continue;
                    }
                    
                    for(OneEntityVulnerableBoxes) | vulnerableBox |
                    {
                        if(DoHitboxesOverlap(attackBox, vulnerableBox))
                        {
                            // Generate Hit event.

                            std.debug.print("Hitboxes overlap!!\n", .{});
                        }
                    }
                }
            }
        }
    }

    pub fn Execute(self: *CollisionSystem, gameState: *GameState) !void
    {
        
        var VulnerableScratchCount : usize = 0;
        var AttackScratchCount : usize = 0;

        // Preprocessing step. Generate hitboxes used to check collision.
        var entity: usize = 0;
        while (entity < gameState.entityCount) : (entity += 1)
        {

            // Before building the scratch hitbox data, we clear it out each frame.                   
            self.AttackSlices[entity] = self.AttackHitboxScratch[0..0];
            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[0..0];
            
            const entityOffset = gameState.physicsComponents[entity].position;

            const component = &gameState.stateMachineComponents[entity];
            const timeline = &gameState.timelineComponents[entity];
            
            const CurrentState = component.stateMachine.CurrentState;

            var actionName : []const u8 = "";
            if(component.stateMachine.Registery.CombatStates[@enumToInt(CurrentState)]) |state|
            {
                actionName = state.Name;
            }

            if(gameState.gameData) | gameData |
            {
                if(entity >= gameData.Characters.items.len)
                {
                    continue; 
                }

                // Get all the hitboxes for the current action.
                if(CharacterData.FindAction(gameData.Characters.items[entity], gameData.ActionMaps.items[entity], actionName)) | actionData |
                {
                                    
                    // Gather attack boxes    
                    {
                        // Here we insert the translated hitboxes for the action into AttackHitboxScratch
                        const atkCount = GetTranslatedActiveHitboxes(actionData.AttackHitboxGroups.items, entityOffset, 
                                            self.AttackHitboxScratch[AttackScratchCount..], timeline.framesElapsed);

                        // Store the slice for this entity that points to a range on the hitbox scratch array
                        if(atkCount > 0)
                        {
                            self.AttackSlices[entity] = self.AttackHitboxScratch[ AttackScratchCount .. atkCount ];
                        }
                        else
                        {
                             self.AttackSlices[entity] = self.AttackHitboxScratch[0 .. 0 ];
                        }

                        AttackScratchCount += atkCount;
                    }

                    // Gather vulnerable boxes
                    {
                        // Here we insert the translated hitboxes for the action into VulnerableHitboxScratch
                        const vulCount = GetTranslatedActiveHitboxes(actionData.VulnerableHitboxGroups.items, entityOffset, 
                                 self.VulnerableHitboxScratch[VulnerableScratchCount..], timeline.framesElapsed);


                        if(vulCount > 0)
                        {
                            // Store the slice for this entity that points to a range on the hitbox scratch array
                            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[ VulnerableScratchCount .. vulCount ];
                        }
                        else
                        {
                            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[0 .. 0];
                        }

                        VulnerableScratchCount += vulCount;
                    }
                }
            }
        }

        self.CollisionPhase(gameState);
    }
};

test "Initializing the collision system"
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();
    var collisionSystem : CollisionSystem = try CollisionSystem.init(ArenaAllocator.allocator());
    _ = collisionSystem;
}

test "Testing getting translated hitboxes"
{
    var Allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer Allocator.deinit();

    var HitboxGroupList = std.ArrayList(CharacterData.HitboxGroup).init(Allocator.allocator());

    var HitboxGroupData = try CharacterData.HitboxGroup.init(Allocator.allocator());
    try HitboxGroupList.append(HitboxGroupData);
    try HitboxGroupList.append(HitboxGroupData);

    try HitboxGroupList.items[0].Hitboxes.append(.{});
    try HitboxGroupList.items[0].Hitboxes.append(.{});
    
    var hitboxScratch: [10]CharacterData.Hitbox = [_]CharacterData.Hitbox{.{}} ** 10;

    const count = GetTranslatedActiveHitboxes(HitboxGroupList.items, math.IntVector2D{}, hitboxScratch[0..], 0);

    try std.testing.expect(count == 2);
}

// test "Test clearing out scratch hitbox data each frame"
// {
//     var ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
//     var collisionSystem : CollisionSystem = try CollisionSystem.init(ArenaAllocator.allocator());

//     _ = collisionSystem;
//     //var Allocator = ArenaAllocator.allocator();

//     // Our game state
//     var gameState = try GameState.GameState.init(ArenaAllocator.allocator());

//     if(gameState.gameData) | *gameData |
//     {
//         var Character = try CharacterData.CharacterProperties.init(ArenaAllocator.allocator());
//         // Add a test character
//         try gameData.Characters.append(Character);
//     }
    
//     // try std.testing.expect(collisionSystem.AttackerEntityBoxes.items.len == 2);
//     // try std.testing.expect(collisionSystem.DefenderEntityBoxes.items.len == 2);

//     try collisionSystem.Execute(&gameState);
// }