const std = @import("std");



pub const Hitbox = struct
{
    top: i32 = 0,
    left: i32 = 0,
    bottom: i32 = 0,
    right: i32 = 0,
};

pub const HitboxGroup = struct
{
    StartFrame: i32 = 0,
    Duration: i32 = 1,
    
    Hitboxes: std.ArrayList(Hitbox),

    const Self = @This();
    pub fn jsonStringify(
            value: Self,
            options: std.json.StringifyOptions,
            out_stream: anytype) !void 
    {            
            try std.json.stringify(.{
                .StartFrame = value.StartFrame,
                .Duration = value.Duration,
                .Hitboxes = value.Hitboxes.items
            } , options, out_stream);
    }
    
    pub fn init(allocator: std.mem.Allocator) !HitboxGroup {
        return HitboxGroup {
            .Hitboxes = std.ArrayList(Hitbox).init(allocator),
        };
    }

    pub fn IsActiveOnFrame(self: HitboxGroup, frame: i32) bool
    {
        return (frame >= self.StartFrame) and (frame < (self.StartFrame + self.Duration));
    }
};


pub const ActionProperties = struct
{
    Duration: i32 = 0,
    VulnerableHitboxGroups: std.ArrayList(HitboxGroup),
    AttackHitboxGroups: std.ArrayList(HitboxGroup),

    const Self = @This();
    pub fn jsonStringify(
            value: Self,
            options: std.json.StringifyOptions,
            out_stream: anytype) !void 
    {            
            try std.json.stringify(.{
                .Duration = value.Duration,
                .VulnerableHitboxGroups = value.VulnerableHitboxGroups.items,
                .AttackHitboxGroups = value.AttackHitboxGroups.items,
            } , options, out_stream);
    }

    pub fn init(allocator: std.mem.Allocator) !ActionProperties {
        return ActionProperties {            
            .VulnerableHitboxGroups = std.ArrayList(HitboxGroup).init(allocator),
            .AttackHitboxGroups = std.ArrayList(HitboxGroup).init(allocator),
        };
    }
};

pub const CharacterProperties = struct 
{
    MaxHealth : i32 = 10000,
    Actions: std.ArrayList(ActionProperties),

    // Deinitialize with `deinit`
    pub fn init(allocator: std.mem.Allocator) !CharacterProperties {
        return CharacterProperties {
            .Actions = std.ArrayList(ActionProperties).init(allocator),
        };
    }

    // Serialization Support
    const Self = @This();
    pub fn jsonStringify(
            value: Self,
            options: std.json.StringifyOptions,
            out_stream: anytype) !void 
    {            
            try std.json.stringify(.{
                .MaxHealth = value.MaxHealth,
                .Actions = value.Actions.items,
            } , options, out_stream);
    }
};



test "Test HitboxGroup.IsActiveOnFrame()"
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var hitboxGroup = HitboxGroup
    { 
        .StartFrame = 2,
        .Duration = 5,
        .Hitboxes = std.ArrayList(Hitbox).init(ArenaAllocator.allocator())
    };

    try std.testing.expect(hitboxGroup.IsActiveOnFrame(2));
    try std.testing.expect(!hitboxGroup.IsActiveOnFrame(7));
    try std.testing.expect(!hitboxGroup.IsActiveOnFrame(1));
}


test "Testing resizable array." 
{   

    {

        var CharacterArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        var group = HitboxGroup
        { 
            .Hitboxes = std.ArrayList(Hitbox).init(CharacterArenaAllocator.allocator())
        };

        try group.Hitboxes.append(Hitbox{.left = 0, .top = 0, .bottom = 200, .right = 400});

        try std.testing.expect(group.Hitboxes.items.len == 1);

        try std.testing.expect(group.Hitboxes.items[0].right == 400);
        try std.testing.expect(group.Hitboxes.items[0].bottom == 200);
    }


}


test "Test writing character data to a json file"
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();

    var Character = try CharacterProperties.init(Allocator);

    var Action = try ActionProperties.init(Allocator);

    try Character.Actions.append(Action);
    try Character.Actions.append(Action);

    var HitboxGroupData = try HitboxGroup.init(Allocator);

    try HitboxGroupData.Hitboxes.append(.{});

    try Character.Actions.items[0].VulnerableHitboxGroups.append(HitboxGroupData);
        
    const file = try std.fs.cwd().createFile("character_data_test.json", .{});
    defer(file.close());

    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var string = std.ArrayList(u8).init(fba.allocator());

    try std.json.stringify(Character, .{.whitespace = .{}}, string.writer());


    try file.writeAll(buffer[0..string.items.len]);
}

// test "Test parsing a json file!"
// {
//     const file = try std.fs.cwd().openFile("prototyping/testinput.json", .{.read = true});
//     defer(file.close());


//     var buffer: [1024]u8 = undefined;

//     var bytesRead = try file.readAll(&buffer);

//     var message = buffer[0..bytesRead];

//     var stream = std.json.TokenStream.init(message);

//     // Requires an allocator to parse JSON string values.
//     var allocBuffer: [1024]u8 = undefined;
//     var fba = std.heap.FixedBufferAllocator.init(&allocBuffer);

//     const data = try std.json.parse(TestJsonStruct, &stream, .{ .allocator = fba.allocator()});
    
//     try std.testing.expect(data.a == 42);
//     try std.testing.expectEqualStrings(data.b, "The World!");

// }

