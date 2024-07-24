const std = @import("std");
const character_data = @import("character_data.zig");
const rl = @import("raylib");

pub const AssetTypeTag = enum {
    Empty,
    Character,
    Texture,
    ImageSequence,
};

pub const AssetType = union(AssetTypeTag) {
    Empty: u8,
    Character: *character_data.CharacterProperties,
    Texture: *character_data.Texture,
    ImageSequence: *character_data.SequenceTexRef,
};

pub const AssetInfo = struct {
    type: AssetType,
    path: []const u8,
    full_path: []const u8,
};

// Reference to an asset on disk that can be loaded
pub fn LoadableAssetReference(comptime T: type) type {
    _ = T;
    return struct {
        path: []const u8 = "",
    };
}

pub fn GetAssetName(asset: AssetInfo) []const u8 {
    switch (asset.type) {
        AssetType.Empty => return "Empty",
        AssetType.Character => return "Character",
        AssetType.Texture => return "Texture",
        AssetType.ImageSequence => return "ImageSequence",
    }
}

pub fn GetAssetNameSentinal(asset: AssetInfo) [:0]const u8 {
    switch (asset.type) {
        AssetType.Empty => return "Empty",
        AssetType.Character => return "Character",
        AssetType.Texture => return "Texture",
        AssetType.ImageSequence => return "ImageSequence",
    }
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

    pub fn loadAsset(self: *Self, comptime T: type, path: [:0]const u8) !void {
        if (self.asset_map.contains(path)) return;
        const ptr: [*:0]const u8 = @ptrCast(path);
        const copied_key: []u8 = self.allocator.dupe(u8, path[0..std.mem.len(ptr)]) catch |err| {
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

        const loaded_asset: AssetType = try T.loadAsset(fullPath_slice, self.allocator);

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
        _ = try character_data.saveAsset(asset, full_path, self.allocator);

        try self.loadAsset(T, relative_path);
    }

    pub fn getAsset(self: *const Self, path: []const u8) AssetInfo {
        const ptr: [*:0]const u8 = @ptrCast(path);
        const key = path[0..std.mem.len(ptr)];

        if (self.asset_map.contains(key)) {
            if (self.asset_map.get(key)) |value| {
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

test "Test Initializing Asset Storage" {
    const storage = try Storage.init(std.testing.allocator);
    _ = storage;
}
