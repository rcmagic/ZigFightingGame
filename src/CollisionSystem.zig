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

fn CollisionSystem(gameState: *GameSimulation.GameState) void
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

    const AttackBoxes: [10]CharacterData.HitboxGroup = .{} ** 10;
    const VulnerableBoxes: [10]CharacterData.HitboxGroup = .{} ** 10;

    var attackEntity: usize = 0;
    while (attackEntity < gameState.entityCount) 
    {        
        const attackBox = AttackBoxes[attackEntity]        ;

        var defendEntity: usize = 0;
        while(defendEntity < gameState.entityCount)
        {
            // Don't check an attacker against itself.
            if(attackEntity == defendEntity) 
            {
                continue;
            }

            const vulnerableBox = VulnerableBoxes[defendEntity];
            if(DoHitboxesOverlap(attackBox, vulnerableBox))
            {
                // Generate Hit event.
            }

            defendEntity += 1;
        }

        attackEntity += 1;
    }
    _ = AttackBoxes;
    _ = VulnerableBoxes;
}
