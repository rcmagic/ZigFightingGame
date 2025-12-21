const std = @import("std");
const rl = @import("raylib");
const asset = @import("asset.zig");
const gameState = @import("GameState.zig");
const stateMachine = @import("ActionStates/StateMachine.zig");
const input = @import("input.zig");

fn stringifyField(field: anytype, name: [:0]const u8, jws: anytype) !void {
    const T = @TypeOf(field);
    switch (@typeInfo(T)) {
        .@"fn" => {},
        // Currenly only support slices
        .pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .slice => {
                    try jws.objectField(name);
                    try jws.write(field);
                },
                else => unreachable,
            }
        },
        .@"enum", .enum_literal => {
            try jws.objectField(name);
            try jws.write(field);
        },
        .@"struct" => {
            try jws.objectField(name);
            try stringifyValue(field, jws);
        },
        .int, .bool => {
            try jws.objectField(name);
            try jws.write(field);
        },
        else => {},
    }
}

fn stringifyValue(value: anytype, jws: anytype) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .@"fn" => {},
        // .@"enum", .@"enum"Literal => {
        //     try jws.write(value);
        // },
        .@"struct" => |structInfo| {
            if (@hasField(T, "items")) {
                try jws.beginArray();
                for (@field(value, "items")) |arrayItem| {
                    try stringifyValue(arrayItem, jws);
                }
                try jws.endArray();
            } else {
                try jws.beginObject();
                inline for (structInfo.fields) |field| {
                    try stringifyField(@field(value, field.name), field.name, jws);
                }
                try jws.endObject();
            }
        },
        .int => {
            try jws.write(value);
        },

        else => {

            //jws.write(value);
        },
    }
}

pub const Hitbox = struct {
    top: i32 = 0,
    left: i32 = 0,
    bottom: i32 = 0,
    right: i32 = 0,

    const Self = @This();
    pub fn SetLocation(self: *Self, x: i32, y: i32) void {
        self.right = x + (self.right - self.left);
        self.bottom = y - (self.top - self.bottom);
        self.left = x;
        self.top = y;
    }

    pub fn SetWidth(self: *Self, width: i32) void {
        const center = @divFloor((self.left + self.right), 2);
        const half = @divFloor(width, 2);
        self.left = center - half;
        self.right = center + half;
    }

    pub fn SetHeight(self: *Self, height: i32) void {
        const center = @divFloor((self.top + self.bottom), 2);
        const half = @divFloor(height, 2);
        self.bottom = center - half;
        self.top = center + half;
    }

    pub fn Width(self: *Self) i32 {
        return self.right - self.left;
    }

    pub fn Height(self: *Self) i32 {
        return self.top - self.bottom;
    }
};

pub const HitboxGroup = struct {
    start_frame: i32 = 0,
    duration: i32 = 1,

    hitboxes: std.array_list.Managed(Hitbox),

    const Self = @This();
    // pub fn jsonStringify(value: Self, options: std.json.StringifyOptions, out_stream: anytype) !void {
    //     try std.json.stringify(.{ .start_frame = value.start_frame, .duration = value.duration, .hitboxes = value.hitboxes.items }, options, out_stream);
    // }

    pub fn init(allocator: std.mem.Allocator) !HitboxGroup {
        return HitboxGroup{
            .hitboxes = std.array_list.Managed(Hitbox).init(allocator),
        };
    }

    pub fn isActiveOnFrame(self: HitboxGroup, frame: i32) bool {
        return (frame >= self.start_frame) and (frame < (self.start_frame + self.duration));
    }
};

pub const HitProperty = struct {
    hitStun: i32 = 0,
    guardStun: i32 = 0,
    hitStop: i32 = 0,
    knockBack: i32 = 0,
    isLaunch: bool = false,
    airKnockback: i32 = 0,
    launchVelocityY: i32 = 0,
    isGrab: bool = false,
};

pub const AttackProperty = struct {
    hitbox_groups: std.array_list.Managed(HitboxGroup),
    hit_property: HitProperty,

    pub fn init(allocator: std.mem.Allocator) !AttackProperty {
        return AttackProperty{
            .hit_property = .{},
            .hitbox_groups = std.array_list.Managed(HitboxGroup).init(allocator),
        };
    }
};

pub const GrabProperty: type = struct {
    start_frame: i32 = 0,
    duration: i32 = 1,
    grab_distance: i32 = 0,

    pub fn isActiveOnFrame(self: GrabProperty, frame: i32) bool {
        return (frame >= self.start_frame) and (frame < (self.start_frame + self.duration));
    }

    pub const metaData = .{ .start_frame = .{ .min_value = 0 } };
};

pub const ImageRange = struct {
    sequence: []const u8 = "",
    index: i32 = 0,
    start: i32 = 0,
    duration: i32 = 1,

    pub fn isActiveOnFrame(self: ImageRange, frame: i32) bool {
        return (frame >= self.start) and (frame < (self.start + self.duration));
    }
};

pub const ActionInput = struct {
    action: asset.LoadableAssetReference(asset.AssetTypeTag.Action) = .{},
    motion: input.MotionNames = .None,
    button: input.InputNames = .Attack,
};

pub const ActionProperties = struct {
    name: []const u8 = "",
    combat_state: stateMachine.CombatStateID = .Standing,
    duration: i32 = 0,
    isLooping: bool = false,
    isSpecial: bool = false,

    vulnerable_hitbox_groups: std.array_list.Managed(HitboxGroup),
    push_hitbox_groups: std.array_list.Managed(HitboxGroup),

    attack_property: AttackProperty,

    grab_properties: std.array_list.Managed(GrabProperty),

    animation_timeline: std.array_list.Managed(ImageRange),

    const Self = @This();

    pub fn jsonStringify(value: @This(), jws: anytype) !void {
        try stringifyValue(value, jws);
    }

    pub fn init(allocator: std.mem.Allocator) !ActionProperties {
        return ActionProperties{
            .vulnerable_hitbox_groups = std.array_list.Managed(HitboxGroup).init(allocator),
            .push_hitbox_groups = std.array_list.Managed(HitboxGroup).init(allocator),
            .attack_property = try AttackProperty.init(allocator),
            .grab_properties = std.array_list.Managed(GrabProperty).init(allocator),
            .animation_timeline = std.array_list.Managed(ImageRange).init(allocator),
        };
    }

    pub fn initIgnoreError(allocator: std.mem.Allocator) ActionProperties {
        return ActionProperties{
            .vulnerable_hitbox_groups = std.array_list.Managed(HitboxGroup).init(allocator),
            .push_hitbox_groups = std.array_list.Managed(HitboxGroup).init(allocator),
            .attack_property = try AttackProperty.init(allocator),
            .grab_properties = std.array_list.Managed(GrabProperty).init(allocator),
            .animation_timeline = std.array_list.Managed(ImageRange).init(allocator),
        };
    }

    pub fn getActiveImage(self: ActionProperties, frame: i32) ImageRange {
        for (self.animation_timeline.items) |image| {
            if (image.isActiveOnFrame(frame)) {
                return image;
            }
        }

        return ImageRange{};
    }
};
var DefaultAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub const DefaultActionProperties: ActionProperties = ActionProperties.initIgnoreError(DefaultAllocator.allocator());

pub fn findAction(character: CharacterProperties, map: std.StringHashMap(*const ActionProperties), ActionName: []const u8) *const ActionProperties {
    _ = character;
    if (map.get(ActionName)) |action| {
        return action;
    }
    return &DefaultActionProperties;
}

pub fn generateActionNameMap(character: *const CharacterProperties, allocator: std.mem.Allocator) !std.StringHashMap(*const ActionProperties) {
    var ActionNameMap = std.StringHashMap(*const ActionProperties).init(allocator);
    for (character.actions.items) |*action| {
        try ActionNameMap.putNoClobber(action.name, action);
    }

    for (character.action_assets.items) |action| {
        switch (action.type) {
            .Action => {
                std.debug.print("generated mapping: {s}\n", .{@typeName(@TypeOf(action))});
                try ActionNameMap.putNoClobber(action.type.Action.name, action.type.Action);
            },
            else => {},
        }
    }

    return ActionNameMap;
}

// Stores the textures used in an image sequence. Use the referenced image index
// to get the associated texture.
pub const SequenceTexRef = struct {
    textures: std.array_list.Managed(rl.Texture2D),

    pub fn init(allocator: std.mem.Allocator) !SequenceTexRef {
        return SequenceTexRef{ .textures = std.array_list.Managed(rl.Texture2D).init(allocator) };
    }
};

pub fn generateImageSequenceMap(character: CharacterProperties, allocator: std.mem.Allocator) !std.StringHashMap(usize) {
    var SequenceNameMap = std.StringHashMap(usize).init(allocator);

    for (character.image_sequences.items, 0..) |sequence, index| {
        try SequenceNameMap.putNoClobber(sequence.name, index);
    }

    return SequenceNameMap;
}

pub fn loadTexture(path: []const u8, allocator: std.mem.Allocator) !rl.Texture2D {
    // Need a null terminate string for the raylib function
    const load_path = try allocator.dupeZ(u8, path);
    defer allocator.free(load_path);
    return rl.loadTexture(@ptrCast(load_path));
}

// Sequences are loaded in the same order as the character data asset.
pub fn loadSequenceImages(character: CharacterProperties, allocator: std.mem.Allocator) !std.array_list.Managed(SequenceTexRef) {
    var imageSequences = std.array_list.Managed(SequenceTexRef).init(allocator);

    for (character.image_sequences.items) |sequence| {
        try imageSequences.append(try SequenceTexRef.init(allocator));
        var sequenceTexRef = &imageSequences.items[imageSequences.items.len - 1];

        for (sequence.images.items) |*image| {
            try gameState.AssetStorage.loadAsset(Texture, image.asset.path);
            const textureAsset: asset.AssetInfo = gameState.AssetStorage.getAsset(image.asset.path);
            try sequenceTexRef.textures.append(textureAsset.type.Texture.Texture);
        }
    }

    return imageSequences;
}

// A single image with an offset.
pub const Image = struct {
    asset: asset.LoadableAssetReference(asset.AssetTypeTag.Texture) = .{},
    x: i32 = 0,
    y: i32 = 0,
};

// A list of images associated with an sequence name
pub const ImageSequence = struct {
    name: []const u8 = "",
    images: std.array_list.Managed(Image),

    pub fn init(allocator: std.mem.Allocator) !ImageSequence {
        return ImageSequence{ .images = std.array_list.Managed(Image).init(allocator) };
    }
};

pub const CharacterProperties = struct {
    const Self = @This();

    image_sequences: std.array_list.Managed(ImageSequence),

    max_health: i32 = 10000,
    default_pushbox: Hitbox = .{},
    grabbable_distance: i32 = 50000,
    actions: std.array_list.Managed(ActionProperties),
    action_assets: std.array_list.Managed(asset.LoadableAssetReference(asset.AssetTypeTag.Action)),
    action_inputs: std.array_list.Managed(ActionInput),

    // Deinitialize with `deinit`
    pub fn init(allocator: std.mem.Allocator) !CharacterProperties {
        return CharacterProperties{
            .actions = std.array_list.Managed(ActionProperties).init(allocator),
            .action_assets = std.array_list.Managed(asset.LoadableAssetReference(.Action)).init(allocator),
            .action_inputs = std.array_list.Managed(ActionInput).init(allocator),
            .image_sequences = std.array_list.Managed(ImageSequence).init(allocator),
        };
    }

    pub fn postLoad(self: *Self) !void {
        _ = self;
        std.debug.print("Character Settings. postLoad()\n", .{});

        // try GameState.AssetStorage.loadAsset(
        //     std.meta.Child(std.meta.TagPayload(AssetType, tag)),
        //     self.path,
        // );
    }

    // Serialization Support
    pub fn jsonStringify(value: @This(), jws: anytype) !void {
        try stringifyValue(value, jws);
    }

    pub fn findSequence(self: *CharacterProperties, map: std.StringHashMap(usize), SequenceName: []const u8) ?*ImageSequence {
        if (map.get(SequenceName)) |index| {
            return &self.image_sequences.items[index];
        }
        return null;
    }

    pub const metaData = .{
        .max_health = .{ .min_value = 0 },
        .grabbable_distance = .{ .min_value = 0 },
    };
};

pub const Texture = struct {
    Texture: rl.Texture2D,
    // Deinitialize with `deinit`
    pub fn init(allocator: std.mem.Allocator) !Texture {
        _ = allocator;
        return .{};
    }

    pub fn readAsset(path: []const u8, allocator: std.mem.Allocator) !asset.AssetType {
        const data: *Texture = try allocator.create(Texture);
        data.*.Texture = try loadTexture(path, allocator);
        return .{ .Texture = data };
    }
};

const MaxAssetBufferSize = 1024 * 512;
pub fn loadCharacterAsset(path: []const u8, allocator: std.mem.Allocator) !?CharacterProperties {
    var dir = try std.fs.openDirAbsolute(gameState.AssetStorage.base_director, .{});
    defer dir.close();
    const file = try dir.openFile(path, .{});
    defer file.close();

    var buffer: [MaxAssetBufferSize]u8 = undefined;
    const bytesRead = try file.readAll(&buffer);
    const message = buffer[0..bytesRead];

    // var p = std.json.Parser.init(allocator, false);
    // defer p.deinit();
    // var tree = try p.parse(message);
    // defer tree.deinit();

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, message, .{});
    defer parsed.deinit();
    const root = parsed.value;

    const thing = try parseJsonValue(CharacterProperties, root, allocator);
    return thing;
}

pub fn saveAsset(character_asset: CharacterProperties, path: []const u8, allocator: std.mem.Allocator) !void {
    _ = allocator;
    const file = std.fs.cwd().createFile(
        path,
        .{},
    ) catch |err| switch (err) {
        else => {
            std.debug.print("File Error saving {s}: {s} \n", .{ path, @errorName(err) });
            return err;
        },
    };
    defer (file.close());

    var buffer: [MaxAssetBufferSize]u8 = undefined;
    var writer: std.Io.Writer = std.Io.Writer.fixed(&buffer);

    try std.json.Stringify.value(character_asset, .{ .whitespace = .indent_4 }, &writer);

    try file.writeAll(buffer[0..writer.end]);
}

// fn itemType(comptime T: type) ?type {
//     if (@TypeOf(T) == .pointer) {
//         return @field(T, "child");
//     }

//     return null;
// }

fn itemType(comptime T: type) ?type {
    switch (@typeInfo(T)) {
        .pointer => |info| return info.child,
        else => null,
    }
}

fn parseJsonValue(comptime T: type, tree: std.json.Value, allocator: std.mem.Allocator) !?T {
    switch (@typeInfo(T)) {
        .int => {
            return @intCast(tree.integer);
        },
        .bool => {
            return tree.bool;
        },
        // Currenly only support slices
        .pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .slice => {
                    const output = try allocator.alloc(u8, tree.string.len);
                    errdefer allocator.free(output);
                    @memcpy(output, tree.string);

                    return output;
                },
                else => unreachable,
            }
        },
        // .@"enum" => {
        //     return std.json.parseFromValueLeaky(T, allocator, tree, .{});
        // },
        .@"struct" => |structInfo| {
            const is_array_list: bool = switch (@typeInfo(T)) {
                .@"struct" => @hasField(T, "items"),
                else => false,
            };

            // ArrayLists are handled as a special case. We serialize ArrayList as JSON arrays
            // rather than objects.
            if (is_array_list) {
                var instanceOfArrayList = T.init(allocator);
                const thing = instanceOfArrayList.items;
                const item_type = itemType(@TypeOf(thing));

                // Array lists are stored as JSON arrays.
                for (tree.array.items) |itemValue| {
                    if (item_type) |itemTypeValidated| {
                        if (try parseJsonValue(itemTypeValidated, itemValue, allocator)) |item| {
                            try instanceOfArrayList.append(item);
                        }
                    }
                }

                return instanceOfArrayList;
            } else {
                var instanceOfStruct: T = undefined;

                if (@hasDecl(T, "init")) {
                    instanceOfStruct = try T.init(allocator);
                } else {
                    instanceOfStruct = .{};
                }

                inline for (structInfo.fields) |field| {
                    const valueOptional = tree.object.get(field.name);
                    if (valueOptional) |value| {
                        const thing = parseJsonValue(field.type, value, allocator) catch unreachable;
                        if (thing) |item| {
                            @field(instanceOfStruct, field.name) = item;
                        }
                    }
                }

                return instanceOfStruct;
            }
        },
        else => {},
    }

    return null;
}

fn writeJsonValue(comptime T: type, tree: std.json.Value, allocator: std.mem.Allocator) !?T {
    switch (@typeInfo(T)) {
        .int => {
            return @intCast(tree.integer);
        },
        .bool => {
            return tree.bool;
        },
        // Currenly only support slices
        .pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .slice => {
                    const output = try allocator.alloc(u8, tree.string.len);
                    errdefer allocator.free(output);
                    @memcpy(output, tree.string);

                    return output;
                },
                else => unreachable,
            }
        },
        .@"struct" => |structInfo| {
            const is_array_list: bool = switch (@typeInfo(T)) {
                .@"struct" => @hasField(T, "items"),
                else => false,
            };

            // ArrayLists are handled as a special case. We serialize ArrayList as JSON arrays
            // rather than objects.
            if (is_array_list) {
                var instanceOfArrayList = T.init(allocator);
                const thing = instanceOfArrayList.items;
                const item_type = itemType(@TypeOf(thing));

                // Array lists are stored as JSON arrays.
                for (tree.array.items) |itemValue| {
                    if (item_type) |itemTypeValidated| {
                        if (try parseJsonValue(itemTypeValidated, itemValue, allocator)) |item| {
                            try instanceOfArrayList.append(item);
                        }
                    }
                }

                return instanceOfArrayList;
            } else {
                var instanceOfStruct: T = undefined;

                if (@hasDecl(T, "init")) {
                    instanceOfStruct = try T.init(allocator);
                } else {
                    instanceOfStruct = .{};
                }

                inline for (structInfo.fields) |field| {
                    const valueOptional = tree.object.get(field.name);
                    if (valueOptional) |value| {
                        const thing = parseJsonValue(field.type, value, allocator) catch unreachable;
                        if (thing) |item| {
                            @field(instanceOfStruct, field.name) = item;
                        }
                    }
                }

                return instanceOfStruct;
            }
        },
        else => {},
    }

    return null;
}

test "Test HitboxGroup.isActiveOnFrame()" {
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var hitboxGroup = HitboxGroup{ .start_frame = 2, .duration = 5, .hitboxes = std.array_list.Managed(Hitbox).init(ArenaAllocator.allocator()) };

    try std.testing.expect(hitboxGroup.isActiveOnFrame(2));
    try std.testing.expect(!hitboxGroup.isActiveOnFrame(7));
    try std.testing.expect(!hitboxGroup.isActiveOnFrame(1));
}

test "Testing resizable array." {
    {
        var CharacterArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        var group = HitboxGroup{ .hitboxes = std.array_list.Managed(Hitbox).init(CharacterArenaAllocator.allocator()) };

        try group.hitboxes.append(Hitbox{ .left = 0, .top = 0, .bottom = 200, .right = 400 });

        try std.testing.expect(group.hitboxes.items.len == 1);

        try std.testing.expect(group.hitboxes.items[0].right == 400);
        try std.testing.expect(group.hitboxes.items[0].bottom == 200);
    }
}

// test "Deserialize an empty struct" {
//     // Test that we can read a struct with no fields.

//     const noFieldStruct = struct {};
//     const noFieldAssetJson = "{}";

//     var p = std.json.Parser.init(std.testing.allocator, false);
//     defer p.deinit();
//     var tree = try p.parse(noFieldAssetJson);
//     defer tree.deinit();

//     const loadedAsset = try parseJsonValue(noFieldStruct, tree.root, std.testing.allocator);
//     try std.testing.expect(loadedAsset != null);
// }

// test "Deserialize a struct with a single integer field" {
//     const oneFieldStruct = struct { value: i32 = 0 };
//     const oneFieldAssetJson = "{\"value\": 25}";

//     var p = std.json.Parser.init(std.testing.allocator, false);
//     defer p.deinit();
//     var tree = try p.parse(oneFieldAssetJson);
//     defer tree.deinit();

//     const loadedAsset = try parseJsonValue(oneFieldStruct, tree.root, std.testing.allocator);

//     try std.testing.expect(loadedAsset != null);
//     if (loadedAsset) |asset| {
//         try std.testing.expect(asset.value == 25);
//     }
// }

// test "Deserialize a struct with a single string field" {
//     const oneFieldStruct = struct { message: []u8 = "" };
//     const oneFieldAssetJson = "{\"message\": \"hello zig!\"}";

//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     var p = std.json.Parser.init(allocator, false);
//     defer p.deinit();
//     var tree = try p.parse(oneFieldAssetJson);
//     defer tree.deinit();

//     const loadedAsset = try parseJsonValue(oneFieldStruct, tree.root, allocator);

//     try std.testing.expect(loadedAsset != null);
//     if (loadedAsset) |asset| {
//         try std.testing.expectEqualStrings(asset.message, "hello zig!");
//     }
// }

// test "Deserialize a struct with a child struct field" {
//     const oneChildStructFieldStruct = struct { child: struct { value: i32 = 0 } = .{} };
//     const oneChildStructFieldStructJson = "{\"child\": {\"value\" : 35}}";

//     var p = std.json.Parser.init(std.testing.allocator, false);
//     defer p.deinit();
//     var tree = try p.parse(oneChildStructFieldStructJson);
//     defer tree.deinit();

//     const loadedAsset = try parseJsonValue(oneChildStructFieldStruct, tree.root, std.testing.allocator);

//     try std.testing.expect(loadedAsset != null);
//     if (loadedAsset) |asset| {
//         try std.testing.expect(asset.child.value == 35);
//     }
// }

// test "Deserialize a struct with an ArrayList" {
//     const oneFieldStructArrayList = struct {
//         numbers: std.array_list.Managed(i32),
//         const Self = @This();
//         fn init(allocator: std.mem.Allocator) !Self {
//             return Self{ .numbers = std.array_list.Managed(i32).init(allocator) };
//         }
//     };

//     const oneFieldStructArrayListJson = "{\"numbers\": [5, 9, 20, 52]}";

//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     var p = std.json.Parser.init(allocator, false);
//     defer p.deinit();
//     var tree = try p.parse(oneFieldStructArrayListJson);
//     defer tree.deinit();

//     const loadedAsset = try parseJsonValue(oneFieldStructArrayList, tree.root, allocator);

//     try std.testing.expect(loadedAsset != null);
//     if (loadedAsset) |asset| {
//         try std.testing.expect(asset.numbers.items.len == 4);
//         try std.testing.expect(asset.numbers.items[2] == 20);
//     }
// }

// test "Test CharacterProperties action name map lookup" {
//     var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     const Allocator = ArenaAllocator.allocator();

//     var Character = try CharacterProperties.init(Allocator);

//     var Action = try ActionProperties.init(Allocator);

//     Action.name = "Jump";
//     try Character.actions.append(Action);

//     Action.name = "Run";
//     try Character.actions.append(Action);

//     const map = try generateActionNameMap(Character, Allocator);
//     try std.testing.expect(findAction(Character, map, "Jump") != null);
//     try std.testing.expect(findAction(Character, map, "Run") != null);
//     try std.testing.expect(findAction(Character, map, "FlyToTheMoon") == null);
// }

// test "Test writing character data to a json file" {
//     var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     const Allocator = ArenaAllocator.allocator();

//     var Character = try CharacterProperties.init(Allocator);

//     const Action = try ActionProperties.init(Allocator);

//     try Character.actions.append(Action);
//     try Character.actions.append(Action);

//     var HitboxGroupData = try HitboxGroup.init(Allocator);

//     try HitboxGroupData.hitboxes.append(.{});

//     try Character.actions.items[0].vulnerable_hitbox_groups.append(HitboxGroupData);

//     const file = try std.fs.cwd().createFile("test.txt", .{});
//     defer (file.close());

//     var buffer: [2048]u8 = undefined;
//     var fba = std.heap.FixedBufferAllocator.init(&buffer);
//     var string = std.array_list.Managed(u8).init(fba.allocator());

//     try std.json.stringifyArbitraryDepth(Allocator, Character, .{ .whitespace = .indent_4 }, string.writer());

//     try file.writeAll(buffer[0..string.items.len]);
// }

// test "Test Writing Character JSON asset" {
//     var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     const Allocator = ArenaAllocator.allocator();
//     const asset = try loadAsset("assets/test_chara_1.json", Allocator);

//     if (asset) |Character| {
//         try saveAsset(Character, "test_character.txt", Allocator);
//     }
// }
