const std = @import("std");
const math = @import("utils/math.zig");
const character_data = @import("character_data.zig");
const component = @import("component.zig");
const GameState = @import("GameState.zig").GameState;
const common = @import("common.zig");


// Check to see if two hitboxes overlap 
fn do_hitboxes_overlap(a: character_data.Hitbox, b: character_data.Hitbox) bool
{
    const IsNotOverlapping = (a.left > b.right) 
                            or (b.left > a.right) 
                            or (a.bottom > b.top) 
                            or (b.bottom > a.top);
    return !IsNotOverlapping;                      
}

fn get_translated_active_hitboxes(hitboxGroups: []const character_data.HitboxGroup, offset: math.IntVector2D, flipHitbox: bool, hitboxes: []character_data.Hitbox, framesElapsed: i32) usize
{
    var count: usize = 0;
    for(hitboxGroups) | hitboxGroup |
    {                
        if(hitboxGroup.isActiveOnFrame(framesElapsed))
        {
            for(hitboxGroup.hitboxes.items) | hitbox |
            {
                const translateBox = if(flipHitbox) common.translate_hitbox_flipped(hitbox, offset) else common.translate_hitbox(hitbox, offset);                            

                hitboxes[count] = translateBox;
                count += 1;
            }
        }
    }

    return count;
}


pub const CollisionSystem = struct 
{
    // Working memory to pass between the collision system stages
    VulnerableHitboxScratch: [100]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 100,
    AttackHitboxScratch: [100]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 100,

    VulnerableSlices : [10][]const character_data.Hitbox = undefined, 
    AttackSlices : [10][]const character_data.Hitbox = undefined,


    pub fn init(allocator: std.mem.Allocator) !CollisionSystem
    {   _ = allocator;
        return CollisionSystem{};
    }

    pub fn collision_phase(self: *CollisionSystem, gameState: *GameState) !void
    {

        // Clear all hit events
        gameState.hitEvents.shrinkRetainingCapacity(0);

        const activeAttackSlices = self.AttackSlices[0..gameState.entityCount];
        const activeVulnerableSlices = self.VulnerableSlices[0..gameState.entityCount];

        // Loop through all the active attacking entities's vulnerable boxes.
        for( activeAttackSlices ) | OneEntityAttackBoxes, attackerIndex |
        {                        

            
            // Don't let an action hit more than once
            if(gameState.reaction_components[attackerIndex].attackHasHit)
            {
                continue;
            }

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
                        if(do_hitboxes_overlap(attackBox, vulnerableBox))
                        {
                            // Make sure the attack won't hit more than once.
                            gameState.reaction_components[attackerIndex].attackHasHit = true;

                            // Generate Hit event.
                            std.debug.print("Hitboxes overlap!!\n", .{});
                            try gameState.hitEvents.append(.{.attackerID = attackerIndex, .defenderID = defenderIndex, .hitStun = 25, .guardStun = 15, .hitStop = 10, .knockBack = 10000 });
                        }
                    }
                }
            }
        }
    }

    pub fn execute(self: *CollisionSystem, gameState: *GameState) !void
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
            
            const entityOffset = gameState.physics_components[entity].position;
            const facingLeft = gameState.physics_components[entity].facingLeft;

            const state_machine = &gameState.state_machine_components[entity];
            const timeline = &gameState.timeline_components[entity];
            
            const CurrentState = state_machine.stateMachine.CurrentState;

            var actionName : []const u8 = "";
            if(state_machine.stateMachine.Registery.CombatStates[@enumToInt(CurrentState)]) |state|
            {
                actionName = state.name;
            }

            if(gameState.gameData) | gameData |
            {
                if(entity >= gameData.Characters.items.len)
                {
                    continue; 
                }

                // Get all the hitboxes for the current action.
                if(character_data.findAction(gameData.Characters.items[entity], gameData.ActionMaps.items[entity], actionName)) | actionData |
                {
                                    
                    // Gather attack boxes    
                    {
                        // Here we insert the translated hitboxes for the action into AttackHitboxScratch
                        const atkCount = get_translated_active_hitboxes(actionData.attack_hitbox_groups.items, entityOffset, facingLeft,
                                            self.AttackHitboxScratch[AttackScratchCount..], timeline.framesElapsed);

                        // Store the slice for this entity that points to a range on the hitbox scratch array
                        if(atkCount > 0)
                        {
                            self.AttackSlices[entity] = self.AttackHitboxScratch[ AttackScratchCount .. (AttackScratchCount + atkCount) ];
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
                        const vulCount = get_translated_active_hitboxes(actionData.vulnerable_hitbox_groups.items, entityOffset, facingLeft,
                                 self.VulnerableHitboxScratch[VulnerableScratchCount..], timeline.framesElapsed);


                        if(vulCount > 0)
                        {
                            // Store the slice for this entity that points to a range on the hitbox scratch array
                            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[ VulnerableScratchCount .. (VulnerableScratchCount + vulCount) ];
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

        try self.collision_phase(gameState);
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

    var HitboxGroupList = std.ArrayList(character_data.HitboxGroup).init(Allocator.allocator());

    var HitboxGroupData = try character_data.HitboxGroup.init(Allocator.allocator());
    try HitboxGroupList.append(HitboxGroupData);
    try HitboxGroupList.append(HitboxGroupData);

    try HitboxGroupList.items[0].hitboxes.append(.{});
    try HitboxGroupList.items[0].hitboxes.append(.{});
    
    var hitboxScratch: [10]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 10;

    const count = get_translated_active_hitboxes(HitboxGroupList.items, math.IntVector2D{}, hitboxScratch[0..], 0);

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
//         var Character = try character_data.CharacterProperties.init(ArenaAllocator.allocator());
//         // Add a test character
//         try gameData.Characters.append(Character);
//     }
    
//     // try std.testing.expect(collisionSystem.AttackerEntityBoxes.items.len == 2);
//     // try std.testing.expect(collisionSystem.DefenderEntityBoxes.items.len == 2);

//     try collisionSystem.execute(&gameState);
// }