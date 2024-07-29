const std = @import("std");
const character_data = @import("character_data.zig");
const rl = @import("raylib");
const GameState = @import("GameState.zig");

pub const AssetTypeTag = enum {
    Empty,
    Character,
    Action,
    Texture,
    ImageSequence,
};

pub const AssetType = union(AssetTypeTag) {
    Empty: u8,
    Character: *character_data.CharacterProperties,
    Action: *character_data.ActionProperties,
    Texture: *character_data.Texture,
    ImageSequence: *character_data.SequenceTexRef,
};

pub const AssetInfo = struct {
    type: AssetType,
    path: []const u8 = "",
    full_path: []const u8 = "",
};

// Reference to an asset on disk that can be loaded
//pub fn LoadableAssetReference(comptime T: type) type {
pub fn LoadableAssetReference(comptime tag: AssetTypeTag) type {
    //_ = T;
    return struct {
        const Self = @This();

        asset_tag: AssetTypeTag = tag,
        path: []const u8 = "",

        pub fn postLoad(self: *Self) !void {
            std.debug.print("postLoad() for {s}\n", .{self.path});

            GameState.AssetStorage.loadAsset(
                std.meta.Child(std.meta.TagPayload(AssetType, tag)),
                self.path,
            ) catch {
                std.debug.print("Failed to load asset reference at path: \"{s}\"\n", .{self.path});
            };
        }
    };
}

pub fn GetAssetName(asset: AssetInfo) []const u8 {
    switch (asset.type) {
        AssetType.Empty => return "Empty",
        AssetType.Character => return "Character",
        AssetType.Action => return "Action",
        AssetType.Texture => return "Texture",
        AssetType.ImageSequence => return "ImageSequence",
    }
}

pub fn MakeAssetType(asset: anytype) AssetType {
    switch (@TypeOf(asset)) {
        *character_data.CharacterProperties => return .{ .Character = asset },
        *character_data.ActionProperties => return .{ .Action = asset },
        *character_data.Texture => return .{ .Texture = asset },
        else => return .{ .Empty = 0 },
    }
}

pub fn GetAssetNameSentinal(asset: AssetInfo) [:0]const u8 {
    switch (asset.type) {
        AssetType.Empty => return "Empty",
        AssetType.Character => return "Character",
        AssetType.Action => return "Action",
        AssetType.Texture => return "Texture",
        AssetType.ImageSequence => return "ImageSequence",
    }
}

const MaxAssetBufferSize = 1024 * 512;
pub fn saveAsset(T: anytype, path: []const u8, allocator: std.mem.Allocator) !void {
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
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var string = std.ArrayList(u8).init(fba.allocator());

    try std.json.stringifyArbitraryDepth(allocator, T, .{ .whitespace = .indent_4 }, string.writer());

    try file.writeAll(buffer[0..string.items.len]);
}

pub fn readAsset(path: []const u8, comptime T: type, allocator: std.mem.Allocator) !AssetType {
    var dir = try std.fs.openDirAbsolute(GameState.AssetStorage.base_director, .{});
    defer dir.close();
    const file = try dir.openFile(path, .{});
    defer file.close();

    var buffer: [MaxAssetBufferSize]u8 = undefined;
    const bytesRead = try file.readAll(&buffer);
    const message = buffer[0..bytesRead];

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, message, .{});
    defer parsed.deinit();
    const root = parsed.value;

    const thing = try parseJsonValue(T, root, allocator);

    if (thing) |real_thing| {
        const data = try allocator.create(T);
        data.* = real_thing;

        return MakeAssetType(data);
    }

    return .{ .Empty = 0 };
}

pub const Storage = struct {
    asset_map: std.StringHashMap(AssetInfo),
    allocator: std.mem.Allocator,

    // Base director for the assets
    base_director: []const u8 = "",

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Storage{
            .asset_map = std.StringHashMap(AssetInfo).init(allocator),
            .allocator = allocator,
            .base_director = "",
        };
    }

    pub fn loadAsset(self: *Self, comptime T: type, path: []const u8) !void {
        if (self.asset_map.contains(path)) return;
        const copied_key: []u8 = self.allocator.dupe(u8, path[0..path.len]) catch |err| {
            _ = self.asset_map.remove(path);
            return err;
        };

        // Standardize path directory seperator
        std.mem.replaceScalar(u8, copied_key, '\\', '/');

        if (self.asset_map.contains(copied_key)) {
            // need to free key if not used.
            self.asset_map.allocator.free(copied_key);
            return;
        }

        const fullPath_buf = try self.allocator.alloc(u8, self.base_director.len + copied_key.len + 1);

        const fullPath_slice = try std.fmt.bufPrint(fullPath_buf, "{s}/{s}", .{
            self.base_director,
            copied_key,
        });

        const loaded_asset: AssetType = blk: {
            // Assets may provide custom file reading.
            if (@hasDecl(T, "readAsset")) break :blk try T.readAsset(fullPath_slice, self.allocator);
            break :blk try readAsset(path, T, self.allocator);
        };

        std.debug.print("Loaded Asset: {s}\n", .{copied_key});

        try self.asset_map.putNoClobber(copied_key, AssetInfo{
            .type = loaded_asset,
            .path = copied_key,
            .full_path = fullPath_buf,
        });
    }

    // Load asset give a full path to the asset.
    pub fn loadAssetFullPath(self: *Self, comptime T: type, path: [:0]const u8) !void {
        const relative_path: [:0]const u8 = std.mem.span(path)[self.base_director.len + 1 ..];
        try self.loadAsset(T, relative_path);
    }

    // Load asset given a full path to the asset. C string version.
    pub fn loadAssetFullPathCStr(self: *Self, comptime T: type, path: [*c]const u8) !void {
        const relative_path: [:0]const u8 = std.mem.span(path)[self.base_director.len + 1 ..];
        try self.loadAsset(T, relative_path);
    }

    // Create an asset given a full path to the asset. C string version.
    pub fn createAssetFullPathCStr(self: *Self, comptime T: type, path: [*c]const u8) !void {
        const relative_path: [:0]const u8 = std.mem.span(path)[self.base_director.len + 1 ..];

        const asset = try T.init(self.allocator);

        const full_path: [:0]const u8 = std.mem.span(path)[0..];
        _ = try saveAsset(asset, full_path, self.allocator);

        try self.loadAsset(T, relative_path);
    }

    pub fn getAsset(self: *const Self, path: []const u8) AssetInfo {
        if (self.asset_map.contains(path)) {
            if (self.asset_map.get(path)) |value| {
                return value;
            }
        }

        return .{
            .type = .{ .Empty = 0 },
            .path = path,
            .full_path = "",
        };
    }
};

fn itemType(comptime T: type) ?type {
    switch (@typeInfo(T)) {
        .Pointer => |info| return info.child,
        else => null,
    }
}

fn parseJsonValue(comptime T: type, tree: std.json.Value, allocator: std.mem.Allocator) !?T {
    switch (@typeInfo(T)) {
        .Int => {
            return @intCast(tree.integer);
        },
        .Bool => {
            return tree.bool;
        },
        // Currenly only support slices
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .Slice => {
                    const output = try allocator.alloc(u8, tree.string.len);
                    errdefer allocator.free(output);
                    @memcpy(output, tree.string);

                    return output;
                },
                else => unreachable,
            }
        },
        .Enum => {
            return try std.json.parseFromValueLeaky(T, allocator, tree, .{});
        },
        .Struct => |structInfo| {
            const is_array_list: bool = switch (@typeInfo(T)) {
                .Struct => @hasField(T, "items"),
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

                // Perform anything that needs to be done after a struct is loaded.
                if (@hasDecl(T, "postLoad")) {
                    try instanceOfStruct.postLoad();
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
        .Int => {
            return @intCast(tree.integer);
        },
        .Bool => {
            return tree.bool;
        },
        // Currenly only support slices
        .Pointer => |ptrInfo| {
            switch (ptrInfo.size) {
                .Slice => {
                    const output = try allocator.alloc(u8, tree.string.len);
                    errdefer allocator.free(output);
                    @memcpy(output, tree.string);

                    return output;
                },
                else => unreachable,
            }
        },
        .Struct => |structInfo| {
            const is_array_list: bool = switch (@typeInfo(T)) {
                .Struct => @hasField(T, "items"),
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

test "Test Initializing Asset Storage" {
    const storage = try Storage.init(std.testing.allocator);
    _ = storage;
}
