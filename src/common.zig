const std = @import("std");
const assert = std.debug.assert;
const math = @import("utils/math.zig");
const CharacterData = @import("CharacterData.zig");

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
    for (action.VulnerableHitboxGroups.items) |hitboxGroup| {
        if (hitboxGroup.IsActiveOnFrame(frame)) {
            for (hitboxGroup.Hitboxes.items) |hitbox| {
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

    defer action.VulnerableHitboxGroups.deinit();

    try action.VulnerableHitboxGroups.append(try CharacterData.HitboxGroup.init(allocator));

    action.VulnerableHitboxGroups.items[0].StartFrame = 0;
    action.VulnerableHitboxGroups.items[0].Duration = 50;

    try action.VulnerableHitboxGroups.items[0].Hitboxes.append(CharacterData.Hitbox{ .top = 500, .left = -500, .bottom = 0, .right = 500 });

    defer action.VulnerableHitboxGroups.items[0].Hitboxes.deinit();


    var hitboxPool: [10]CharacterData.Hitbox = [_]CharacterData.Hitbox{.{}} ** 10;

    const frame = 5;
    const position = math.IntVector2D{ .x = 200, .y = 400 };
    const count = GetVulnerableBoxes(hitboxPool[0..], action, frame, position);

    const testingBox = action.VulnerableHitboxGroups.items[0].Hitboxes.items[0];
    const hitbox = hitboxPool[0];

    try std.testing.expect(count == 1);
    try std.testing.expect(action.VulnerableHitboxGroups.items[0].IsActiveOnFrame(frame));
    try std.testing.expect(hitbox.top == (position.y + testingBox.top));
    try std.testing.expect(hitbox.left == (position.x + testingBox.left));
    try std.testing.expect(hitbox.bottom == (position.y + testingBox.bottom));
    try std.testing.expect(hitbox.right == (position.x + testingBox.right));
}
