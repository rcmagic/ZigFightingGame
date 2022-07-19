const std = @import("std");
const rl = @import("raylib");

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

pub const ImageRange = struct
{
    Sequence:  []const u8 = "",
    Index: i32 = 0,
    Start:  i32 = 0,
    Duration: i32 = 1,
};

pub const ActionProperties = struct
{
    Duration: i32 = 0,
    IsLooping: bool = false,
    VulnerableHitboxGroups: std.ArrayList(HitboxGroup),
    AttackHitboxGroups: std.ArrayList(HitboxGroup),

    AnimationTimeline: std.ArrayList(ImageRange),

    Name: []const u8 = "",

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
            .AnimationTimeline = std.ArrayList(ImageRange).init(allocator)
        };
    }
};

pub fn FindAction(character: CharacterProperties, map: std.StringHashMap(usize), ActionName: []const u8) ?*ActionProperties
{
    if(map.get(ActionName)) | index |
    {            
        return &character.Actions.items[index];
    }
    return null;
}

pub fn FindSequence(character: CharacterProperties, map: std.StringHashMap(usize), SequenceName: []const u8) ?*ImageSequence
{
    if(map.get(SequenceName)) | index |
    {            
        return &character.ImageSequences.items[index];
    }
    return null;
}


pub fn GenerateActionNameMap(character: CharacterProperties, allocator: std.mem.Allocator) !std.StringHashMap(usize)
{

    var ActionNameMap = std.StringHashMap(usize).init(allocator);
    for(character.Actions.items) | action, index |
    {
        try ActionNameMap.putNoClobber(action.Name, index);
    }

    return ActionNameMap;
}


pub const SequenceTexRef = struct
{
    textures: std.ArrayList(rl.Texture2D),

    pub fn init(allocator: std.mem.Allocator) !SequenceTexRef {
        return SequenceTexRef {
            .textures = std.ArrayList(rl.Texture2D).init(allocator)
        };
    }
};

pub fn GenerateImageSequenceMap(character: CharacterProperties, allocator: std.mem.Allocator) !std.StringHashMap(usize)
{
    var SequenceNameMap = std.StringHashMap(usize).init(allocator);

    for(character.ImageSequences.items) | sequence, index |
    {
        try SequenceNameMap.putNoClobber(sequence.Name, index);
    }

    return SequenceNameMap;
}

// Sequences are loaded in the same order as the character data asset.
pub fn LoadSequenceImages(character: CharacterProperties, allocator: std.mem.Allocator) !std.ArrayList(SequenceTexRef)
{
    var imageSequences = std.ArrayList(SequenceTexRef).init(allocator);

    for(character.ImageSequences.items) | sequence |
    {        
        try imageSequences.append(try SequenceTexRef.init(allocator));
        var sequenceTexRef = &imageSequences.items[imageSequences.items.len - 1];

        for(sequence.Images.items) | image |
        {
            // Need a better way to handle conversion from non-null terminated strings to c strings.
            const source = try allocator.alloc(u8, image.Source.len+1); 
            defer allocator.free(source);
            std.mem.copy(u8, source, image.Source);
            source[source.len-1] = 0;
            try sequenceTexRef.textures.append(rl.LoadTexture(@ptrCast([*c]const u8, source)));
        }
    }

    return imageSequences;
}

// A single image with an offset.
pub const Image = struct
{
    Source: []const u8 = "",
    x: i32 = 0,
    y: i32 = 0,
};

// A list of images associated with an sequence name
pub const ImageSequence = struct{
    Name: []const u8 = "",
    Images: std.ArrayList(Image),

    pub fn init(allocator: std.mem.Allocator) !ImageSequence {
        return ImageSequence {
            .Images = std.ArrayList(Image).init(allocator)
        };
    }
};

pub const CharacterProperties = struct 
{
    MaxHealth : i32 = 10000,
    Actions: std.ArrayList(ActionProperties),

    ImageSequences: std.ArrayList(ImageSequence),

    // Deinitialize with `deinit`
    pub fn init(allocator: std.mem.Allocator) !CharacterProperties {
        return CharacterProperties {
            .Actions = std.ArrayList(ActionProperties).init(allocator),
            .ImageSequences = std.ArrayList(ImageSequence).init(allocator)
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

pub fn LoadAsset(path: []const u8, allocator: std.mem.Allocator) !?CharacterProperties
{
    const file = try std.fs.cwd().openFile(path, .{.read = true});    
    defer(file.close());

    var buffer: [4*2048]u8 = undefined;
    const bytesRead = try file.readAll(&buffer);
    const message = buffer[0..bytesRead];

    var p = std.json.Parser.init(allocator, false);
    defer p.deinit();
    var tree = try p.parse(message);
    defer tree.deinit();

    var thing = try ParseJsonValue(CharacterProperties, tree.root, allocator);
    return thing;
}

fn IsArrayList(comptime T: type) bool
{
    switch(@typeInfo(T))
    {
        .Struct => { return @hasField(T, "items"); },
        else => {}
    }

    return false;
}

fn ItemType(comptime T: type)? type
{
    switch(@typeInfo(T)) 
    {
        .Pointer => |info| return info.child,
        else => null
    }
}


fn ParseJsonValue(comptime T: type, tree: std.json.Value, allocator: std.mem.Allocator) !?T
{
    switch(@typeInfo(T))
    {
        .Int =>
        {
            return @intCast(T, tree.Integer);
        },
        .Bool =>
        {
            return tree.Bool;
        },
        // Currenly only support slices
        .Pointer => |ptrInfo|
        {
            switch(ptrInfo.size)
            {
                .Slice => 
                {
                    const output = try allocator.alloc(u8, tree.String.len);
                    errdefer allocator.free(output);
                    std.mem.copy(u8, output, tree.String);
                    
                    return output;
                },
                else => unreachable
            }
        },
        .Struct => |structInfo|
        {
            comptime var isArrayList = IsArrayList(T);
            
            // ArrayLists are handled as a special case. We serialize ArrayList as JSON arrays
            // rather than objects.
            if(isArrayList)
            {           
                var instanceOfArrayList = T.init(allocator);
                const itemType = ItemType(@TypeOf(instanceOfArrayList.items));


                // Array lists are stored as JSON arrays.
                for(tree.Array.items) | itemValue |
                {                        
                    if(itemType) | itemTypeValidated |
                    {                                                 
                        if(try ParseJsonValue(itemTypeValidated, itemValue, allocator)) | item |
                        {
                            try instanceOfArrayList.append(item);
                        }
                    }
                }

                return instanceOfArrayList;
            }
            else
            {                
                var instanceOfStruct: T = undefined;

                if(@hasDecl(T, "init"))
                {
                    instanceOfStruct = try T.init(allocator);
                }
                else 
                {
                    instanceOfStruct = .{};
                }
                
                inline for(structInfo.fields) | field |
                {
                    const valueOptional = tree.Object.get(field.name);
                    if(valueOptional) | value |
                    {
                        const thing = ParseJsonValue(field.field_type, value, allocator) catch unreachable;
                        if(thing) | item |
                        {
                            @field(instanceOfStruct, field.name) = item;
                        }
                    }
                }

                return instanceOfStruct;
            }
        },
        else => {}
    }

    return null;
}




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


test "Deserialize an empty struct"
{
    // Test that we can read a struct with no fields.

    const noFieldStruct = struct {};
    const noFieldAssetJson = "{}";

    var p = std.json.Parser.init(std.testing.allocator, false);
    defer p.deinit();
    var tree = try p.parse(noFieldAssetJson);
    defer tree.deinit();

    const loadedAsset = try ParseJsonValue(noFieldStruct, tree.root, std.testing.allocator);
    try std.testing.expect(loadedAsset != null);
   
}

test "Deserialize a struct with a single integer field"
{
    const oneFieldStruct = struct { value: i32 = 0 };
    const oneFieldAssetJson = "{\"value\": 25}";

    var p = std.json.Parser.init(std.testing.allocator, false);
    defer p.deinit();
    var tree = try p.parse(oneFieldAssetJson);
    defer tree.deinit();

    const loadedAsset = try ParseJsonValue(oneFieldStruct, tree.root, std.testing.allocator);

    try std.testing.expect(loadedAsset != null);
    if(loadedAsset) | asset |
    {
        try std.testing.expect( asset.value == 25);
    }
   
}

test "Deserialize a struct with a single string field"
{

    const oneFieldStruct = struct { message: []u8 = "" };
    const oneFieldAssetJson = "{\"message\": \"hello zig!\"}";


    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var p = std.json.Parser.init(allocator, false);
    defer p.deinit();
    var tree = try p.parse(oneFieldAssetJson);
    defer tree.deinit();

    const loadedAsset = try ParseJsonValue(oneFieldStruct, tree.root, allocator);

    try std.testing.expect(loadedAsset != null);
    if(loadedAsset) | asset |
    {        
        try std.testing.expectEqualStrings(asset.message, "hello zig!");
    }
   
}

test "Deserialize a struct with a child struct field"
{
    const oneChildStructFieldStruct = struct { 
        child: struct { value: i32 = 0} = .{}
    };
    const oneChildStructFieldStructJson = "{\"child\": {\"value\" : 35}}";

    var p = std.json.Parser.init(std.testing.allocator, false);
    defer p.deinit();
    var tree = try p.parse(oneChildStructFieldStructJson);
    defer tree.deinit();

    const loadedAsset = try ParseJsonValue(oneChildStructFieldStruct, tree.root, std.testing.allocator);

    try std.testing.expect(loadedAsset != null);
    if(loadedAsset) | asset | 
    {
        try std.testing.expect(asset.child.value == 35);
    }
}

test "Deserialize a struct with an ArrayList"
{    

    const oneFieldStructArrayList = struct { 
        numbers: std.ArrayList(i32),
        const Self = @This();
        fn init(allocator: std.mem.Allocator) !Self
        {
          return Self{ .numbers = std.ArrayList(i32).init(allocator) };
        }
    };

    const oneFieldStructArrayListJson = "{\"numbers\": [5, 9, 20, 52]}";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();


    var p = std.json.Parser.init(allocator, false);
    defer p.deinit();
    var tree = try p.parse(oneFieldStructArrayListJson);
    defer tree.deinit();

    const loadedAsset = try ParseJsonValue(oneFieldStructArrayList, tree.root, allocator);

    try std.testing.expect(loadedAsset != null);
    if(loadedAsset) | asset | 
    {
        try std.testing.expect(asset.numbers.items.len == 4);
        try std.testing.expect(asset.numbers.items[2] == 20);
    }

}


test "Test CharacterProperties action name map lookup"
{
    var ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var Allocator = ArenaAllocator.allocator();

    var Character = try CharacterProperties.init(Allocator);

    var Action = try ActionProperties.init(Allocator);

    Action.Name =  "Jump";
    try Character.Actions.append(Action);    

    Action.Name =  "Run";
    try Character.Actions.append(Action);

    const map = try GenerateActionNameMap(Character, Allocator);
    try std.testing.expect(FindAction(Character, map, "Jump") != null);
    try std.testing.expect(FindAction(Character, map, "Run") != null);
    try std.testing.expect(FindAction(Character, map, "FlyToTheMoon") == null);

}