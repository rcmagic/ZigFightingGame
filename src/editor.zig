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
    @cInclude("sfd.h");
    //@cInclude("tinyfiledialogs.h");
});
const z = @import("zgui");

var ShowPropertyEditor = true;
var ShowActiveActionProperties = true;
var AssetWindowImportMenu = false;
var SelectedEntity: i32 = 0;

// Use for selecting a replacement asset.
var assigning_asset: bool = false;
var assigning_id: z.Ident = 0;
var show_asset_select_popup: bool = false;

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
            .@"struct" => |structInfo| {
                inline for (structInfo.fields) |field| {
                    switch (@typeInfo(field.type)) {
                        .int => {
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

fn TexturePreview(texture: *character_data.Texture, allocator: std.mem.Allocator, meta_data: anytype) void {
    // try GenericPropertyEdit(texture, "", allocator, meta_data);
    _ = texture;
    _ = allocator;
    _ = meta_data;
    // @todo find out what this "TextureRef" this function requires is. chase 2025/12/22
    // z.image(&texture.Texture.id, .{
    //     .w = @floatFromInt(texture.Texture.width),
    //     .h = @floatFromInt(texture.Texture.height),
    // });
}

fn RemoveItem(list: anytype, index: usize) void {
    const deleted = list.orderedRemove(index);
    list.allocator.destroy(&deleted);
}

fn GenericPropertyEdit(property: anytype, name: [:0]const u8, allocator: std.mem.Allocator, meta_data: anytype) !void {
    switch (@typeInfo(@TypeOf(property.*))) {
        .@"enum" => |enum_info| {
            var selected_item = property.*;
            if (z.beginCombo(name, .{ .preview_value = @tagName(property.*) })) {
                inline for (enum_info.fields) |e| {
                    if (z.selectable(e.name, .{ .selected = (@intFromEnum(selected_item) == e.value) })) {
                        selected_item = @enumFromInt(e.value);
                    }
                }
                z.endCombo();

                @constCast(property).* = selected_item;
            }
        },
        .@"struct" => |structInfo| {
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
                        .pointer => |ptrInfo| {
                            switch (@typeInfo(ptrInfo.child)) {
                                .@"struct" => {
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
        .pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .slice => {
                    var editText = [_:0]u8{0} ** 64;
                    std.mem.copyForwards(u8, &editText, property.*);
                    if (z.inputText(name, .{ .buf = &editText })) {
                        const ptr = @as([*c]u8, &editText);
                        const string = editText[0..std.mem.len(ptr)];
                        @constCast(property).* = try allocator.dupe(u8, string);
                        z.textUnformatted("Can't edit since const");
                        //property.* = try allocator.dupe(u8, string);
                    }
                },
                else => {
                    z.separatorText("Unknown Pointer");
                },
            }
        },
        .int => {
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
            @constCast(property).* = @intCast(value);
        },
        .bool => {
            _ = z.checkbox(name, .{ .v = @constCast(property) });
        },
        else => {
            z.separatorText("Unknown Type");
        },
    }
}

const FieldMetaData = struct {
    min_value: i32 = -10000,
};

// Add custom widgets here for asset reference previews.
fn AssetTypeReferencePreview(asset_info: asset.AssetInfo, allocator: std.mem.Allocator, meta_data: anytype) void {
    switch (asset_info.type) {
        .Texture => TexturePreview(asset_info.type.Texture, allocator, meta_data),
        else => {},
    }
}

// Select custom type editors
fn CompTimePropertyEdit(property: anytype, name: [:0]const u8, allocator: std.mem.Allocator, meta_data: anytype) !void {
    if (@TypeOf(property.*) == character_data.Hitbox) {
        HitboxPropertyEdit(property, name, allocator);
    } else if (@TypeOf(property.*) == character_data.Texture) {
        try GenericPropertyEdit(property, "", allocator, meta_data);
        TexturePreview(property, allocator, meta_data);
        //} else if (@TypeOf(property.*) == asset.LoadableAssetReference(asset.AssetTypeTag.Texture)) {
    } else {
        switch (@typeInfo(@TypeOf(property.*))) {
            .@"struct" => {
                if (@hasField(@TypeOf(property.*), "asset_tag")) {
                    z.textUnformatted("Asset Reference");

                    // Replace asset with another asset.
                    if (z.button("Replace", .{})) {
                        assigning_asset = true;
                        assigning_id = z.getPtrId(property);
                    }

                    // Show asset path
                    try GenericPropertyEdit(&property.path, "##", allocator, meta_data);

                    const the_asset = GameState.AssetStorage.getAsset(property.*.path);

                    // set assign when selected
                    if (assigning_asset and (z.getPtrId(property) == assigning_id)) {
                        // Assign asset
                        if (try AssetSelectPopup(property.asset_tag)) |selected_asset| {
                            property.*.path = selected_asset.path;
                            assigning_asset = false;
                            assigning_id = 0;
                        }
                    }

                    // Thumbnail preview of the asset
                    AssetTypeReferencePreview(the_asset, allocator, meta_data);
                } else {
                    try GenericPropertyEdit(property, name, allocator, meta_data);
                }
            },
            else => {
                try GenericPropertyEdit(property, name, allocator, meta_data);
            },
        }
    }
}

var DummyAssetInfo = asset.AssetInfo{ .type = .{ .Empty = 0 }, .path = "", .full_path = "" };
var SelectedAsset: *asset.AssetInfo = &DummyAssetInfo;

// Open a dialog for importing an asset.
fn AssetImporter(comptime T: type, window_title: [*c]const u8, filter_name: [*c]const u8, filter: [*c]const u8) !void {
    var args = c.sfd_Options{
        .title = window_title,
        .filter_name = filter_name,
        .filter = filter,
    };

    // Apparently calling this will change the current working directory so I need to be careful.
    // Consider adding the OFN_NOCHANGEDIR flag to the GetOpenFileName() call in sfd
    const argptr: *[1]c.sfd_Options = &args;
    const result = c.sfd_open_dialog(argptr);

    if (result == null) {
        return;
    }

    try GameState.AssetStorage.loadAssetFullPathCStr(T, result);
}

// Opens a dialog for creating a new asset on the disk and loads that asset.
fn AssetCreator(comptime T: type, window_title: [*c]const u8, filter_name: [*c]const u8, filter: [*c]const u8) !void {
    var args = c.sfd_Options{
        .title = window_title,
        .filter_name = filter_name,
        .filter = filter,
    };

    // Apparently calling this will change the current working directory so I need to be careful.
    // Consider adding the OFN_NOCHANGEDIR flag to the GetOpenFileName() call in sfd
    const argptr: *[1]c.sfd_Options = &args;
    const result = c.sfd_save_dialog(argptr);

    if (result == null) {
        return;
    }

    std.debug.print("Filename for save: {s}", .{result});

    try GameState.AssetStorage.createAssetFullPathCStr(T, result);
}

pub fn AssetSelectWindow(allocator: std.mem.Allocator, asset_tag: ?asset.AssetTypeTag) !*asset.AssetInfo {
    _ = allocator;

    // Asset Selector Window
    if (z.begin("Asset Select", .{ .popen = &ShowPropertyEditor, .flags = .{ .menu_bar = true } })) {
        // Menu Bar
        if (z.beginMenuBar()) {
            // Import Menu
            if (z.beginMenu("Import", true)) {
                if (z.menuItem("Character", .{})) {
                    try AssetImporter(character_data.CharacterProperties, "Import Character Asset", "Character", "*.json");
                } else if (z.menuItem("Action", .{})) {
                    try AssetImporter(character_data.ActionProperties, "Import Action Asset", "Action", "*.json");
                } else if (z.menuItem("Texture", .{})) {
                    try AssetImporter(character_data.Texture, "Import Texture", "Texture", "*.png");
                }

                z.endMenu();
            }

            if (z.beginMenu("Create", true)) {
                if (z.menuItem("Character", .{})) {
                    try AssetCreator(
                        character_data.CharacterProperties,
                        "Create Character Asset",
                        "Character",
                        "*.json",
                    );
                } else if (z.menuItem("Action", .{})) {
                    try AssetCreator(
                        character_data.ActionProperties,
                        "Create Action Asset",
                        "Action",
                        "*.json",
                    );
                }
                z.endMenu();
            }
            z.endMenuBar();
        }
        if (z.beginTable("AssetTable", .{
            .column = 2,
            .flags = .{ .resizable = true },
        })) {
            z.tableSetupColumn("Type", .{});
            z.tableSetupColumn("Path", .{});
            z.tableHeadersRow();

            var it = GameState.AssetStorage.asset_map.iterator();
            while (it.next()) |kv| {
                var show_asset = true;

                if (asset_tag) |tag| {
                    if (kv.value_ptr.type != tag) {
                        show_asset = false;
                    }
                }

                if (show_asset) {
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
        }
        z.endTable();
    }
    z.end();

    return SelectedAsset;
}

// A popup window that allows you to select and get an asset reference.
pub fn AssetSelectPopup(asset_tag: ?asset.AssetTypeTag) !?*asset.AssetInfo {
    var select_asset: ?*asset.AssetInfo = null;

    show_asset_select_popup = assigning_asset;

    // Asset Selector Window
    if (z.begin("Assets", .{ .popen = &show_asset_select_popup, .flags = .{ .menu_bar = true } })) {
        if (z.beginTable("AssetTable", .{
            .column = 2,
            .flags = .{ .resizable = true },
        })) {
            z.tableSetupColumn("Type", .{});
            z.tableSetupColumn("Path", .{});
            z.tableHeadersRow();

            var it = GameState.AssetStorage.asset_map.iterator();
            while (it.next()) |kv| {
                var show_asset = true;

                if (asset_tag) |tag| {
                    if (kv.value_ptr.type != tag) {
                        show_asset = false;
                    }
                }

                if (show_asset) {
                    z.pushPtrId(kv.value_ptr);
                    z.tableNextRow(.{});
                    _ = z.tableSetColumnIndex(0);

                    if (z.selectable(
                        asset.GetAssetNameSentinal(kv.value_ptr.*),
                        .{
                            .selected = (select_asset == kv.value_ptr),
                            .flags = .{ .span_all_columns = true },
                        },
                    )) {
                        select_asset = kv.value_ptr;
                    }
                    _ = z.tableSetColumnIndex(1);
                    z.textUnformatted(kv.value_ptr.path);
                    z.popId();
                }
            }
        }
        z.endTable();
    }
    z.end();

    assigning_asset = show_asset_select_popup;
    return select_asset;
}

pub fn Tick(gameState: GameState.GameState, allocator: std.mem.Allocator) !void {
    c.rlImGuiBegin();
    defer c.rlImGuiEnd();

    var open = true;
    z.showDemoWindow(&open);

    const selection = try AssetSelectWindow(allocator, null);

    if (z.begin("Properties", .{ .popen = &ShowPropertyEditor, .flags = .{} })) {

        // Use the asset storage
        const entry = selection;

        // @todo Wanna do some code generation here so I don't have to manually do this for all types.
        switch (entry.type) {
            //.AssetType.Empty => return "Empty",
            .Character => {
                if (z.button("Save Character", .{})) {
                    character_data.saveAsset(
                        entry.type.Character.*,
                        entry.full_path,
                        allocator,
                    ) catch {
                        std.debug.print("Any Error", .{});
                    };
                }

                try CompTimePropertyEdit(
                    entry.type.Character,
                    "Character",
                    allocator,
                    .{},
                );
            },
            .Action => {
                if (z.button("Save Asset", .{})) {
                    asset.saveAsset(
                        entry.type.Action.*,
                        entry.full_path,
                        allocator,
                    ) catch {
                        std.debug.print("Any Error", .{});
                    };
                }

                try CompTimePropertyEdit(
                    entry.type.Action,
                    "Action",
                    allocator,
                    .{},
                );
            },
            .Texture => {
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
                    _ = state;
                    actionName = @tagName(CurrentState);
                }

                const actionData = character_data.findAction(
                    gameData.CharacterAssets.items[entity].*,
                    GameState.ActionMaps.items[entity],
                    actionName,
                );
                // Get all the hitboxes for the current action.
                var editActionName = [_]u8{0} ** 64;
                std.mem.copyForwards(u8, &editActionName, actionName);

                if (z.button("Save Character", .{})) {
                    character_data.saveAsset(
                        gameData.CharacterAssets.items[entity].*,
                        "assets/test_chara_1.json",
                        allocator,
                    ) catch {
                        std.debug.print("Any Error!", .{});
                    };
                }

                try CompTimePropertyEdit(@constCast(actionData), editActionName[0 .. actionName.len + 1 :0], allocator, .{});
            }
        }
    }

    z.end();
}
