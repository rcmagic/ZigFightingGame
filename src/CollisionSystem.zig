const std = @import("std");
const GameSimulation = @import("GameSimulation.zig");
const CharacterData = @import("CharacterData.zig");
const Component = @import("Component.zig");
const math = @import("utils/math.zig");


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

fn GetActiveAttackHiboxes(gameState: *const GameSimulation.GameState, entity: usize) ?*CharacterData.HitboxGroup
{
    // Unused for now
    _ = gameState;
    _ = entity;

    // if(gameState.gameData) | gameData |
    // {
    //     gameData.CharacterProperties[entity].
    // }


    return null;
}

const CollisionSystem = struct 
{
    // Working memory to pass between the collision system stages
    AttackerEntityBoxes: std.ArrayList(CharacterData.HitboxGroup),
    DefenderEntityBoxes: std.ArrayList(CharacterData.HitboxGroup),

    fn Init(allocator: std.mem.Allocator) !CollisionSystem
    {
        var Attacker = try std.ArrayList(CharacterData.HitboxGroup).initCapacity(allocator, 10);
        var Defender = try std.ArrayList(CharacterData.HitboxGroup).initCapacity(allocator, 10);
        return CollisionSystem {
                    .AttackerEntityBoxes = Attacker,
                    .DefenderEntityBoxes = Defender
                };
    }

    fn Execute(self: CollisionSystem, gameState: *GameSimulation.GameState) void
    {
        // TODO: Remove when the parameter is used.
        _ = gameState;

        // Preprocessing step. Generated hitboxes used to actually check collision.
        // var entity: usize = 0;
        // while (entity < gameState.entityCount) 
        // {
        //     const entityOffset = gameState.physicsComponent[entity].position;
        //     // Get active attack hitboxes and offset them.
        //     // GetActiveAttackHitboxes(entity);

        //     TranslateHitbox(hitbox, entityOffset);

        //     entity += 1;
        // }

        for(self.AttackerEntityBoxes) | AttackBoxes, attackerIndex |
        {
            for(AttackBoxes) | attackBox |
            {                
                for(self.DefenderEntityBoxes) | VulnerableBoxes, defenderIndex |
                {
                    // Don't check an attacker against itself.
                    if(attackerIndex == defenderIndex) 
                    {
                        continue;
                    }

                    for(VulnerableBoxes) | vulnerableBox |
                    {
                        if(DoHitboxesOverlap(attackBox, vulnerableBox))
                        {
                            // Generate Hit event.
                        }
                    }
                }
            }
        }
    }
};

test "Initializing the collision system"
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var collisionSystem : CollisionSystem = try CollisionSystem.Init(ArenaAllocator.allocator());

    // The collision system currently supports processing 10 attack boxes at a time.
    try std.testing.expect(collisionSystem.AttackerEntityBoxes.capacity == 10);
    try std.testing.expect(collisionSystem.AttackerEntityBoxes.items.len == 0);

    // The collision system currently supports processing 10 vulnerable boxes at a time.
    try std.testing.expect(collisionSystem.DefenderEntityBoxes.capacity == 10);
    try std.testing.expect(collisionSystem.DefenderEntityBoxes.items.len == 0);
}