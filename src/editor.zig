const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const game_simulation = @import("game_simulation.zig");
const GameState = @import("GameState.zig").GameState;
const character_data = @import("character_data.zig");
const CombatStateID = @import("ActionStates/StateMachine.zig").CombatStateID;
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const z = @import("zgui");

var ShowPropertyEditor = true;

fn CoordinateEdit(name: [:0]const u8, coordinate: *i32) void {
    _ = z.dragInt(name, .{ .v = coordinate, .speed = 100 });
}

fn HitboxPropertyEdit(hitbox: *character_data.Hitbox, name: [:0]const u8, allocator: std.mem.Allocator) void {
    if (z.collapsingHeader(name, .{ .default_open = false })) {
        _ = allocator;
        //z.separatorText(@typeName(@TypeOf(hitbox.*)));

        z.pushPtrId(hitbox);
        defer z.popId();

        var x = hitbox.left;
        CoordinateEdit("x", &x);
        var y = hitbox.top;
        CoordinateEdit("y", &y);
        hitbox.SetLocation(x, y);

        var width = hitbox.Width();
        CoordinateEdit("width", &width);
        hitbox.SetWidth(width);

        var height = hitbox.Height();
        CoordinateEdit("height", &height);
        hitbox.SetHeight(height);

        switch (@typeInfo(@TypeOf(hitbox.*))) {
            .Struct => |structInfo| {
                inline for (structInfo.fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .Int => {
                            CoordinateEdit(field.name, &@field(hitbox, field.name));
                        },
                        else => {
                            z.separatorText(field.name);
                        },
                    }
                }
            },
            else => {
                z.separatorText("Unknown Type");
            },
        }
    }
}

fn RemoveItem(list: anytype, index: usize) void {
    const deleted = list.orderedRemove(index);
    list.allocator.destroy(&deleted);
}

fn GenericPropertyEdit(property: anytype, name: [:0]const u8, allocator: std.mem.Allocator) !void {
    switch (@typeInfo(@TypeOf(property.*))) {
        .Struct => |structInfo| {
            if (@hasField(@TypeOf(property.*), "items")) {
                z.pushPtrId(property);
                defer z.popId();
                z.separatorText(name);
                var deleteIndex: i32 = -1;
                z.sameLine(.{});

                const addButtonClicked = z.smallButton("+");

                for (property.items, 0..) |*item, index| {
                    z.pushPtrId(item);
                    defer z.popId();
                    z.indent(.{ .indent_w = 8 });
                    defer z.unindent(.{ .indent_w = 8 });

                    if (z.smallButton("x")) {
                        deleteIndex = @intCast(index);
                    }

                    z.sameLine(.{});
                    const label = z.formatZ("{}", .{index});
                    try CompTimePropertyEdit(item, label, allocator);
                }

                if (deleteIndex >= 0) {
                    RemoveItem(property, @intCast(deleteIndex));
                } else if (addButtonClicked) {
                    switch (@typeInfo(@TypeOf(property.items))) {
                        .Pointer => |ptrInfo| {
                            switch (@typeInfo(ptrInfo.child)) {
                                .Struct => {
                                    var instance: ptrInfo.child = undefined;
                                    if (@hasDecl(ptrInfo.child, "init")) {
                                        instance = try ptrInfo.child.init(allocator);
                                    } else {
                                        instance = .{};
                                    }
                                    try property.append(instance);
                                },
                                else => {
                                    const instance: ptrInfo.child = 0;
                                    try property.append(instance);
                                },
                            }
                        },
                        else => {},
                    }
                }
            } else {
                z.pushPtrId(property);
                defer z.popId();
                if (z.collapsingHeader(name, .{ .default_open = true })) {
                    inline for (structInfo.fields) |field| {
                        try CompTimePropertyEdit(&@field(property, field.name), field.name, allocator);
                    }
                }
            }
        },
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .Slice => {
                    var editText = [_]u8{0} ** 64;
                    std.mem.copyForwards(u8, &editText, property.*);
                    if (z.inputText(name, .{ .buf = &editText })) {
                        const result = try allocator.alloc(u8, editText.len);
                        errdefer allocator.free(result);
                        @memcpy(result, &editText);
                        property.* = result;
                    }
                },
                else => {
                    z.separatorText("Unknown Pointer");
                },
            }
        },
        .Int => {
            var value: i32 = @intCast(property.*);
            _ = z.dragInt(name, .{ .v = &value, .speed = 100 });
            property.* = @intCast(value);
        },
        .Bool => {
            _ = z.checkbox(name, .{ .v = property });
        },
        else => {
            z.separatorText("Unknown Type");
        },
    }
}

fn CompTimePropertyEdit(property: anytype, name: [:0]const u8, allocator: std.mem.Allocator) !void {
    if (@TypeOf(property.*) == character_data.Hitbox) {
        HitboxPropertyEdit(property, name, allocator);
    } else {
        try GenericPropertyEdit(property, name, allocator);
    }
}

pub fn Tick(gameState: GameState, allocator: std.mem.Allocator) !void {
    c.rlImGuiBegin();
    defer c.rlImGuiEnd();

    // var open = true;
    // z.showDemoWindow(&open);

    if (z.begin("Properties", .{ .popen = &ShowPropertyEditor, .flags = .{} })) {
        if (gameState.gameData) |gameData| {
            const entity = 0;
            const stateMachine = &gameState.state_machine_components[entity].stateMachine;
            const CurrentState = stateMachine.CurrentState;

            var actionName: []const u8 = "";
            if (stateMachine.Registery.CombatStates[@intFromEnum(CurrentState)]) |state| {
                actionName = state.name;
            }

            // Get all the hitboxes for the current action.
            if (character_data.findAction(gameData.Characters.items[entity], gameData.ActionMaps.items[entity], actionName)) |actionData| {
                var editActionName = [_]u8{0} ** 64;
                std.mem.copyForwards(u8, &editActionName, actionName);

                if (z.button("Save Character", .{})) {
                    try character_data.saveAsset(gameData.Characters.items[entity], "assets/test_chara_1.json", allocator);
                }
                try CompTimePropertyEdit(&gameData.Characters.items[entity], "Character", allocator);
                try CompTimePropertyEdit(actionData, editActionName[0 .. actionName.len + 1 :0], allocator);
            }
        }
    }
    z.end();
}
