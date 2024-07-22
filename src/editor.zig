const std = @import("std");
const rl = @import("raylib");
const math = @import("utils/math.zig");
const game_simulation = @import("game_simulation.zig");
const GameState = @import("GameState.zig");
const asset = @import("asset.zig");
const character_data = @import("character_data.zig");
const CombatStateID = @import("ActionStates/StateMachine.zig").CombatStateID;
const c = @cImport({
    @cDefine("NO_FONT_AWESOME", "1");
    @cInclude("rlImGui.h");
});
const z = @import("zgui");

var ShowPropertyEditor = true;
var ShowActiveActionProperties = true;
var SelectedEntity: i32 = 0;

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

fn GenericPropertyEdit(property: anytype, name: [:0]const u8, allocator: std.mem.Allocator, meta_data: anytype) !void {
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
                    try CompTimePropertyEdit(item, label, allocator, meta_data);
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

                        // Handle meta data
                        const field_meta = if (@hasDecl(@TypeOf(property.*), "metaData") and @hasField(@TypeOf(@TypeOf(property.*).metaData), field.name))
                            @field(@TypeOf(property.*).metaData, field.name);

                        try CompTimePropertyEdit(&@field(property, field.name), field.name, allocator, field_meta);
                    }
                }
            }
        },
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .Slice => {
                    var editText = [_:0]u8{0} ** 64;
                    std.mem.copyForwards(u8, &editText, property.*);
                    if (z.inputText(name, .{ .buf = &editText })) {
                        const ptr = @as([*c]u8, &editText);
                        const string = editText[0..std.mem.len(ptr)];
                        property.* = try allocator.dupe(u8, string);
                    }
                },
                else => {
                    z.separatorText("Unknown Pointer");
                },
            }
        },
        .Int => {
            var value: i32 = @intCast(property.*);

            var min_value: i32 = -1000;
            var max_value: i32 = 1000;

            if (@TypeOf(meta_data) != void) {
                // handle meta data
                if (@hasField(@TypeOf(meta_data), "min_value")) {
                    min_value = meta_data.min_value;
                }

                if (@hasField(@TypeOf(meta_data), "max_value")) {
                    max_value = meta_data.max_value;
                }
            }
            _ = z.dragInt(name, .{ .v = &value, .speed = 100, .min = min_value, .max = max_value });
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

const FieldMetaData = struct {
    min_value: i32 = -10000,
};

fn CompTimePropertyEdit(property: anytype, name: [:0]const u8, allocator: std.mem.Allocator, meta_data: anytype) !void {
    if (@TypeOf(property.*) == character_data.Hitbox) {
        HitboxPropertyEdit(property, name, allocator);
    } else {
        try GenericPropertyEdit(property, name, allocator, meta_data);
    }
}

var DummyAssetInfo = asset.AssetInfo{ .type = .{ .Empty = 0 }, .path = "" };
var SelectedAsset: *asset.AssetInfo = &DummyAssetInfo;
pub fn AssetSelectWindow(allocator: std.mem.Allocator) !*asset.AssetInfo {
    _ = allocator;
    if (z.begin("Assets", .{ .popen = &ShowPropertyEditor, .flags = .{} })) {
        if (z.beginTable("AssetTable", .{
            .column = 2,
            .flags = .{ .resizable = true },
        })) {
            z.tableSetupColumn("Type", .{});
            z.tableSetupColumn("Path", .{});
            z.tableHeadersRow();

            var it = GameState.AssetStorage.asset_map.iterator();
            while (it.next()) |kv| {
                z.pushPtrId(kv.value_ptr);
                z.tableNextRow(.{});
                _ = z.tableSetColumnIndex(0);

                if (z.selectable(
                    asset.GetAssetNameSentinal(kv.value_ptr.*),
                    .{
                        .selected = (SelectedAsset == kv.value_ptr),
                        .flags = .{ .span_all_columns = true },
                    },
                )) {
                    SelectedAsset = kv.value_ptr;
                }
                _ = z.tableSetColumnIndex(1);
                z.textUnformatted(kv.value_ptr.path);
                z.popId();
            }
        }
        z.endTable();
    }
    z.end();

    return SelectedAsset;
}

pub fn Tick(gameState: GameState.GameState, allocator: std.mem.Allocator) !void {
    c.rlImGuiBegin();
    defer c.rlImGuiEnd();

    var open = true;
    z.showDemoWindow(&open);

    const selection = try AssetSelectWindow(allocator);

    if (z.begin("Properties", .{ .popen = &ShowPropertyEditor, .flags = .{} })) {

        // Use the asset storage
        const entry = selection;

        // @todo Wanna do some code generation here so I don't have to manually do this for all types.
        switch (entry.type) {
            //.AssetType.Empty => return "Empty",
            .Character => {
                if (z.button("Save Character", .{})) {
                    try character_data.saveAsset(entry.type.Character.*, entry.path, allocator);
                }
                try CompTimePropertyEdit(
                    entry.type.Character,
                    "Character",
                    allocator,
                    .{},
                );
            },
            .Texture => {
                z.image(&entry.type.Texture.Texture.id, .{
                    .w = @floatFromInt(entry.type.Texture.Texture.width),
                    .h = @floatFromInt(entry.type.Texture.Texture.height),
                });
                try CompTimePropertyEdit(
                    entry.type.Texture,
                    "Texture",
                    allocator,
                    .{},
                );
            },
            else => {
                z.textUnformatted("Unknown");
            },
        }
    }
    z.end();

    if (z.begin("Active Action Properties", .{ .popen = &ShowActiveActionProperties, .flags = .{} })) {
        if (gameState.gameData) |gameData| {
            _ = z.dragInt("Entity", .{ .v = &SelectedEntity, .min = 0, .max = @intCast(gameData.CharacterAssets.items.len - 1) });

            const entity: usize = @intCast(SelectedEntity);
            // Property for the current performing action.
            if (entity < gameState.state_machine_components.len) {
                const stateMachine = &gameState.state_machine_components[entity].stateMachine;
                const CurrentState = stateMachine.CurrentState;

                var actionName: []const u8 = "";
                if (stateMachine.Registery.CombatStates[@intFromEnum(CurrentState)]) |state| {
                    actionName = state.name;
                }

                // Get all the hitboxes for the current action.
                if (character_data.findAction(gameData.CharacterAssets.items[entity].*, gameData.ActionMaps.items[entity], actionName)) |actionData| {
                    var editActionName = [_]u8{0} ** 64;
                    std.mem.copyForwards(u8, &editActionName, actionName);

                    if (z.button("Save Character", .{})) {
                        try character_data.saveAsset(gameData.CharacterAssets.items[entity].*, "assets/test_chara_1.json", allocator);
                    }

                    try CompTimePropertyEdit(actionData, editActionName[0 .. actionName.len + 1 :0], allocator, .{});
                }
            }
        }
    }

    z.end();
}
