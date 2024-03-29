const std = @import("std");
const assert = std.debug.assert;
const math = @import("utils/math.zig");
const character_data = @import("character_data.zig");
const component = @import("component.zig");

// Conditionally flip the character to face the opponent if not already facing them
pub fn flip_to_face_opponent(physics_component: *component.PhysicsComponent) void {
    if (!physics_component.facingOpponent) {
        physics_component.facingLeft = !physics_component.facingLeft;
        physics_component.facingOpponent = true;
    }
}

// Create a new hitbox translated by the offset provided.
pub fn translate_hitbox(hitbox: character_data.Hitbox, offset: math.IntVector2D) character_data.Hitbox {
    return character_data.Hitbox{ .left = (hitbox.left + offset.x), .top = (hitbox.top + offset.y), .right = (hitbox.right + offset.x), .bottom = (hitbox.bottom + offset.y) };
}

pub fn translate_hitbox_flipped(hitbox: character_data.Hitbox, offset: math.IntVector2D) character_data.Hitbox {
    return character_data.Hitbox{ .left = (-hitbox.right + offset.x), .top = (hitbox.top + offset.y), .right = (-hitbox.left + offset.x), .bottom = (hitbox.bottom + offset.y) };
}

// Get all active vulnerable hitboxes translated by the character's position.
fn get_vulnerable_boxes(
    hitboxPool: []character_data.Hitbox, // out parameter
    action: character_data.ActionProperties,
    frame: i32,
    position: math.IntVector2D,
) usize {
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
                hitboxPool[poolIndex] = character_data.Hitbox{
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
    const allocator = std.testing.allocator;
    var action = try character_data.ActionProperties.init(allocator);

    defer action.vulnerable_hitbox_groups.deinit();

    try action.vulnerable_hitbox_groups.append(try character_data.HitboxGroup.init(allocator));

    action.vulnerable_hitbox_groups.items[0].start_frame = 0;
    action.vulnerable_hitbox_groups.items[0].duration = 50;

    try action.vulnerable_hitbox_groups.items[0].hitboxes.append(character_data.Hitbox{ .top = 500, .left = -500, .bottom = 0, .right = 500 });

    defer action.vulnerable_hitbox_groups.items[0].hitboxes.deinit();

    var hitboxPool: [10]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 10;

    const frame = 5;
    const position = math.IntVector2D{ .x = 200, .y = 400 };
    const count = get_vulnerable_boxes(hitboxPool[0..], action, frame, position);

    const testingBox = action.vulnerable_hitbox_groups.items[0].hitboxes.items[0];
    const hitbox = hitboxPool[0];

    try std.testing.expect(count == 1);
    try std.testing.expect(action.vulnerable_hitbox_groups.items[0].isActiveOnFrame(frame));
    try std.testing.expect(hitbox.top == (position.y + testingBox.top));
    try std.testing.expect(hitbox.left == (position.x + testingBox.left));
    try std.testing.expect(hitbox.bottom == (position.y + testingBox.bottom));
    try std.testing.expect(hitbox.right == (position.x + testingBox.right));
}
