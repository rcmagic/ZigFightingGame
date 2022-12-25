const std = @import("std");
const assert = std.debug.assert;
const math = @import("utils/math.zig");
const CharacterData = @import("CharacterData.zig");
const component = @import("component.zig");


// Conditionally flip the character to face the opponent if not already facing them
pub fn FlipToFaceOpponent(physics_component: *component.PhysicsComponent) void
{
    if(!physics_component.facingOpponent)
    {
        physics_component.facingLeft = !physics_component.facingLeft;
        physics_component.facingOpponent = true;
    }
}

// Create a new hitbox translated by the offset provided.
pub fn TranslateHitbox(hitbox: CharacterData.Hitbox, offset: math.IntVector2D) CharacterData.Hitbox
{
    return CharacterData.Hitbox {   .left   =   (hitbox.left + offset.x), 
                                    .top    =   (hitbox.top + offset.y),
                                    .right  =   (hitbox.right + offset.x),
                                    .bottom =   (hitbox.bottom + offset.y)
    };
}


pub fn TranslateHitboxFlipped(hitbox: CharacterData.Hitbox, offset: math.IntVector2D) CharacterData.Hitbox
{
    return CharacterData.Hitbox {   .left   =   (-hitbox.right + offset.x), 
                                    .top    =   (hitbox.top + offset.y),
                                    .right  =   (-hitbox.left + offset.x),
                                    .bottom =   (hitbox.bottom + offset.y)
    };
}

// Get all active vulnerable hitboxes translated by the character's position.
fn GetVulnerableBoxes(
    hitboxPool: []CharacterData.Hitbox, // out parameter
    action: CharacterData.ActionProperties,
    frame: i32,
    position: math.IntVector2D,
) usize 
{
    var poolIndex: usize = 0;

    // Find all active hitboxes
    for (action.vulnerable_hitbox_groups.items) |hitboxGroup| {
        if (hitboxGroup.isActiveOnFrame(frame)) {
            for (hitboxGroup.hitboxes.items) |hitbox| {
                assert(poolIndex <= hitboxPool.len);

                // If we exceeded the hitbox pool size, return the size of the hitbox pool and write no more hitboxes.
                if (poolIndex >= hitboxPool.len) {
                    return hitboxPool.len;
                }

                // Translate the hitbox by the character position
                hitboxPool[poolIndex] = CharacterData.Hitbox{
                    .top = hitbox.top + position.y,
                    .left = hitbox.left + position.x,
                    .bottom = hitbox.bottom + position.y,
                    .right = hitbox.right + position.x,
                };

                poolIndex += 1;
            }
        }
    }

    return poolIndex;
}

test "Test getting translated hitboxes from an action" {
    var allocator = std.testing.allocator;
    var action = try CharacterData.ActionProperties.init(allocator);

    defer action.vulnerable_hitbox_groups.deinit();

    try action.vulnerable_hitbox_groups.append(try CharacterData.HitboxGroup.init(allocator));

    action.vulnerable_hitbox_groups.items[0].start_frame = 0;
    action.vulnerable_hitbox_groups.items[0].duration = 50;

    try action.vulnerable_hitbox_groups.items[0].hitboxes.append(CharacterData.Hitbox{ .top = 500, .left = -500, .bottom = 0, .right = 500 });

    defer action.vulnerable_hitbox_groups.items[0].hitboxes.deinit();


    var hitboxPool: [10]CharacterData.Hitbox = [_]CharacterData.Hitbox{.{}} ** 10;

    const frame = 5;
    const position = math.IntVector2D{ .x = 200, .y = 400 };
    const count = GetVulnerableBoxes(hitboxPool[0..], action, frame, position);

    const testingBox = action.vulnerable_hitbox_groups.items[0].hitboxes.items[0];
    const hitbox = hitboxPool[0];

    try std.testing.expect(count == 1);
    try std.testing.expect(action.vulnerable_hitbox_groups.items[0].isActiveOnFrame(frame));
    try std.testing.expect(hitbox.top == (position.y + testingBox.top));
    try std.testing.expect(hitbox.left == (position.x + testingBox.left));
    try std.testing.expect(hitbox.bottom == (position.y + testingBox.bottom));
    try std.testing.expect(hitbox.right == (position.x + testingBox.right));
}
