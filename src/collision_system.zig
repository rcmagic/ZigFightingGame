const std = @import("std");
const math = @import("utils/math.zig");
const character_data = @import("character_data.zig");
const component = @import("component.zig");
const GameState = @import("GameState.zig").GameState;
const common = @import("common.zig");

// Check to see if two hitboxes overlap
fn do_hitboxes_overlap(a: character_data.Hitbox, b: character_data.Hitbox) bool {
    const IsNotOverlapping = (a.left > b.right) or (b.left > a.right) or (a.bottom > b.top) or (b.bottom > a.top);
    return !IsNotOverlapping;
}

fn get_translated_active_hitboxes(hitboxGroups: []const character_data.HitboxGroup, offset: math.IntVector2D, flipHitbox: bool, hitboxes: []character_data.Hitbox, framesElapsed: i32) usize {
    var count: usize = 0;
    for (hitboxGroups) |hitboxGroup| {
        if (hitboxGroup.isActiveOnFrame(framesElapsed)) {
            for (hitboxGroup.hitboxes.items) |hitbox| {
                const translateBox = if (flipHitbox) common.translate_hitbox_flipped(hitbox, offset) else common.translate_hitbox(hitbox, offset);

                hitboxes[count] = translateBox;
                count += 1;
            }
        }
    }

    return count;
}

pub const CollisionSystem = struct {
    // Working memory to pass between the collision system stages
    VulnerableHitboxScratch: [100]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 100,
    AttackHitboxScratch: [100]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 100,
    PushHitboxScratch: [100]character_data.Hitbox = [_]character_data.Hitbox{.{}} ** 100,

    VulnerableSlices: [10][]const character_data.Hitbox = undefined,
    AttackSlices: [10][]const character_data.Hitbox = undefined,
    PushSlices: [10][]const character_data.Hitbox = undefined,

    pub fn init(allocator: std.mem.Allocator) !CollisionSystem {
        _ = allocator;
        return CollisionSystem{};
    }

    fn getActionProperties(entity: usize, gameState: *GameState) ?*character_data.ActionProperties {
        if (gameState.gameData) |gameData| {
            const state_machine_component = gameState.state_machine_components[entity];
            var grabber_action_name: []const u8 = "";

            const grabber_state = state_machine_component.stateMachine.CurrentState;
            if (state_machine_component.stateMachine.Registery.CombatStates[@intFromEnum(grabber_state)]) |state| {
                grabber_action_name = state.name;
            }

            return character_data.findAction(
                gameData.CharacterAssets.items[entity].*,
                gameData.ActionMaps.items[entity],
                grabber_action_name,
            );
        }

        return null;
    }

    pub fn grab_collision_phase(gameState: *GameState) !void {
        if (gameState.gameData) |gameData| {
            for (0..gameState.entityCount) |grabber_entity| {
                if (getActionProperties(grabber_entity, gameState)) |grabber_action_properties| {
                    for (0..gameState.entityCount) |other_entity| {

                        // Make sure the grabbing entity doesn't grab itself
                        if (other_entity == grabber_entity) continue;

                        for (grabber_action_properties.grab_properties.items) |grabber_property| {
                            if (grabber_property.isActiveOnFrame(gameState.timeline_components[grabber_entity].framesElapsed)) {
                                const other_character = gameData.CharacterAssets.items[other_entity];
                                // Range check

                                const grabber_physics = gameState.physics_components[grabber_entity];
                                const other_physics = gameState.physics_components[other_entity];

                                const distance = @abs(other_physics.position.x - grabber_physics.position.x);

                                if (distance > (grabber_property.grab_distance + other_character.grabbable_distance)) continue;

                                try gameState.hitEvents.append(.{ .hitProperty = .{ .isGrab = true }, .attackerID = grabber_entity, .defenderID = other_entity });
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn collision_phase(self: *CollisionSystem, gameState: *GameState) !void {
        const activeAttackSlices = self.AttackSlices[0..gameState.entityCount];
        const activeVulnerableSlices = self.VulnerableSlices[0..gameState.entityCount];

        // Loop through all the active attacking entities's vulnerable boxes.
        for (activeAttackSlices, 0..) |OneEntityAttackBoxes, attackerIndex| {

            // Don't let an action hit more than once
            if (gameState.reaction_components[attackerIndex].attackHasHit) {
                continue;
            }

            for (OneEntityAttackBoxes) |attackBox| {
                // Loop through all the active defending entities's vulnerable boxes.
                for (activeVulnerableSlices, 0..) |OneEntityVulnerableBoxes, defenderIndex| {
                    // Don't check an attacker against itself.
                    if (attackerIndex == defenderIndex) {
                        continue;
                    }

                    for (OneEntityVulnerableBoxes) |vulnerableBox| {
                        if (do_hitboxes_overlap(attackBox, vulnerableBox)) {
                            // Make sure the attack won't hit more than once.
                            gameState.reaction_components[attackerIndex].attackHasHit = true;

                            // Allow special canceling when an attack has hit
                            gameState.reaction_components[attackerIndex].attackHasHitForSpecialCancel = true;

                            // Generate Hit event.
                            std.debug.print("Hitboxes overlap!!\n", .{});

                            if (gameState.gameData) |gameData| {
                                const CurrentState = gameState.state_machine_components[attackerIndex].stateMachine.CurrentState;
                                var actionName: []const u8 = "";

                                if (gameState.state_machine_components[attackerIndex].stateMachine.Registery.CombatStates[@intFromEnum(CurrentState)]) |state| {
                                    actionName = state.name;
                                }

                                if (character_data.findAction(gameData.CharacterAssets.items[attackerIndex].*, gameData.ActionMaps.items[attackerIndex], actionName)) |actionData| {
                                    try gameState.hitEvents.append(.{ .hitProperty = actionData.attack_property.hit_property, .attackerID = attackerIndex, .defenderID = defenderIndex });
                                }
                            }
                        }
                    }
                }
            }
        }

        ////////////// PUSH COLLISIONS ///////////////////

        // The amount of overlap of two push boxes along the X-axis
        var overlap_distance_x: i32 = 0;

        const active_push_slices = self.PushSlices[0..gameState.entityCount];
        // Loop through all the push boxes for each entity and check against every other entity
        for (active_push_slices, 0..) |OneEntityAttackBoxes, attackerIndex| {
            for (OneEntityAttackBoxes) |attackBox| {
                // Loop through all the active defending entities's vulnerable boxes.
                for (active_push_slices, 0..) |OneEntityVulnerableBoxes, defenderIndex| {
                    // Don't check an attacker against itself.
                    if (attackerIndex == defenderIndex) {
                        continue;
                    }

                    for (OneEntityVulnerableBoxes) |vulnerableBox| {
                        if (do_hitboxes_overlap(attackBox, vulnerableBox)) {
                            // Calculate the amount of overlap
                            const leftSide = @max(attackBox.left, vulnerableBox.left);
                            const rightSide = @min(attackBox.right, vulnerableBox.right);

                            overlap_distance_x = rightSide - leftSide;

                            // Generate Hit event.
                            std.debug.print("Push boxes overlap {}!!\n", .{overlap_distance_x});
                        }
                    }
                }
            }
        }

        {
            const overlap_half = @divTrunc(overlap_distance_x, 2);

            var positionA = &gameState.physics_components[0].position;
            var positionB = &gameState.physics_components[1].position;

            // Push entities apart
            if (positionA.x < positionB.x) {
                positionA.x -= overlap_half;
                positionB.x += overlap_half;
            } else {
                positionA.x += overlap_half;
                positionB.x -= overlap_half;
            }
        }
    }

    pub fn execute(self: *CollisionSystem, gameState: *GameState) !void {
        var VulnerableScratchCount: usize = 0;
        var AttackScratchCount: usize = 0;
        var PushScratchCount: usize = 0;

        // Preprocessing step. Generate hitboxes used to check collision.
        var entity: usize = 0;
        while (entity < gameState.entityCount) : (entity += 1) {

            // Before building the scratch hitbox data, we clear it out each frame.
            self.AttackSlices[entity] = self.AttackHitboxScratch[0..0];
            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[0..0];
            self.PushSlices[entity] = self.PushHitboxScratch[0..0];

            const entityOffset = gameState.physics_components[entity].position;
            const facingLeft = gameState.physics_components[entity].facingLeft;

            const state_machine = &gameState.state_machine_components[entity];
            const timeline = &gameState.timeline_components[entity];

            const CurrentState = state_machine.stateMachine.CurrentState;

            var actionName: []const u8 = "";
            if (state_machine.stateMachine.Registery.CombatStates[@intFromEnum(CurrentState)]) |state| {
                actionName = state.name;
            }

            if (gameState.gameData) |gameData| {
                if (entity >= gameData.CharacterAssets.items.len) {
                    continue;
                }

                // Get all the hitboxes for the current action.
                if (character_data.findAction(gameData.CharacterAssets.items[entity].*, gameData.ActionMaps.items[entity], actionName)) |actionData| {

                    // Gather attack boxes
                    {
                        // Here we insert the translated hitboxes for the action into AttackHitboxScratch
                        const atkCount = get_translated_active_hitboxes(actionData.attack_property.hitbox_groups.items, entityOffset, facingLeft, self.AttackHitboxScratch[AttackScratchCount..], timeline.framesElapsed);

                        // Store the slice for this entity that points to a range on the hitbox scratch array
                        if (atkCount > 0) {
                            self.AttackSlices[entity] = self.AttackHitboxScratch[AttackScratchCount..(AttackScratchCount + atkCount)];
                        } else {
                            self.AttackSlices[entity] = self.AttackHitboxScratch[0..0];
                        }

                        AttackScratchCount += atkCount;
                    }

                    // Gather vulnerable boxes
                    {
                        // Here we insert the translated hitboxes for the action into VulnerableHitboxScratch
                        const vulCount = get_translated_active_hitboxes(actionData.vulnerable_hitbox_groups.items, entityOffset, facingLeft, self.VulnerableHitboxScratch[VulnerableScratchCount..], timeline.framesElapsed);

                        if (vulCount > 0) {
                            // Store the slice for this entity that points to a range on the hitbox scratch array
                            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[VulnerableScratchCount..(VulnerableScratchCount + vulCount)];
                        } else {
                            self.VulnerableSlices[entity] = self.VulnerableHitboxScratch[0..0];
                        }

                        VulnerableScratchCount += vulCount;
                    }

                    // Gather push boxes
                    {
                        // Here we insert the translated hitboxes for the action into PushHitboxScratch
                        var pushCount = get_translated_active_hitboxes(actionData.push_hitbox_groups.items, entityOffset, facingLeft, self.PushHitboxScratch[PushScratchCount..], timeline.framesElapsed);

                        // Don't allow characters in a grab reaction to be pushed.
                        if (gameState.reaction_components[entity].grabLocked) {}
                        // If there is no push hitbox overrides, use the default push hitbox for the character.
                        else if (pushCount <= 0) {
                            pushCount = 1;
                            // Get the slice of push hitboxes still available after processing previous push boxes.
                            var scratchHitboxes = self.PushHitboxScratch[PushScratchCount..];
                            const hitbox = gameData.CharacterAssets.items[entity].default_pushbox;
                            const translatedBox = if (facingLeft) common.translate_hitbox_flipped(hitbox, entityOffset) else common.translate_hitbox(hitbox, entityOffset);

                            scratchHitboxes[0] = translatedBox;
                        }

                        // Store the slice for this entity that points to a range on the hitbox scratch array
                        self.PushSlices[entity] = self.PushHitboxScratch[PushScratchCount..(PushScratchCount + pushCount)];
                        PushScratchCount += pushCount;
                    }
                }
            }
        }

        // Clear all hit events
        gameState.hitEvents.shrinkRetainingCapacity(0);

        try grab_collision_phase(gameState);

        try self.collision_phase(gameState);
    }
};

test "Initializing the collision system" {
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer ArenaAllocator.deinit();
    const collisionSystem: CollisionSystem = try CollisionSystem.init(ArenaAllocator.allocator());
    _ = collisionSystem;
}

test "Testing getting translated hitboxes" {
    var Allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer Allocator.deinit();

    var HitboxGroupList = std.ArrayList(character_data.HitboxGroup).init(Allocator.allocator());

    const HitboxGroupData = try character_data.HitboxGroup.init(Allocator.allocator());
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
