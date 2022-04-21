const std = @import("std");


pub const Hitbox = struct
{
    top: i32,
    left: i32,
    bottom: i32,
    right: i32,
};

pub const HitboxGroup = struct
{
    StartFrame: i32 = 0,
    Duration: i32 = 1,

    Hitboxes: std.ArrayList(Hitbox)
};


pub const ActionProperties = struct
{
    Duration: i32,
    HitboxGroups: std.ArrayList(HitboxGroup)
};

pub const CharacterProperties = struct 
{
    MaxHealth : i32,
    Actions: std.ArrayList(ActionProperties)
};



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

