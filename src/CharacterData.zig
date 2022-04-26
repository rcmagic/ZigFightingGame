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

