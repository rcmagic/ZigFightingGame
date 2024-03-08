const std = @import("std");
const character_data = @import("character_data.zig");

pub const AssetTypeTag = enum {
    Empty,
    Character,
    ImageSequence,
};

pub const AssetType = union(AssetTypeTag) {
    Empty: u8,
    Character: *character_data.CharacterProperties,
    ImageSequence: *character_data.SequenceTexRef,
};

pub const AssetInfo = struct {
    type: AssetType,
    path: [:0]const u8,
};

pub const Storage = struct {
    asset_map: std.StringHashMap(AssetInfo),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Storage{
            .asset_map = std.StringHashMap(AssetInfo).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn loadAsset(self: *Self, comptime T: type, path: [:0]const u8) !void {
        if (self.asset_map.contains(path)) return;

        const loaded_asset: AssetType = try T.loadAsset(path, self.allocator);
        try self.*.asset_map.putNoClobber(path, AssetInfo{ .type = loaded_asset, .path = path });
    }

    pub fn getAsset(self: *Self, path: [:0]const u8) AssetInfo {
        if (self.asset_map.contains(path)) {
            if (self.asset_map.get(path)) |value| {
                return value;
            }
        }

        return .{ .type = .{ .Empty = 0 }, .path = path };
    }
};

test "Test Initializing Asset Storage" {
    const storage = try Storage.init(std.testing.allocator);
    _ = storage;
}
