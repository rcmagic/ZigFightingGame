const std = @import("std");

test "Testing" 
{
    var allocator = std.testing.allocator;

    var gameData: ?std.ArrayList(i32) = null;

    gameData = try std.ArrayList(i32).initCapacity(allocator, 5);

    // Deinit now
    gameData.?.deinit();

    gameData = try std.ArrayList(i32).initCapacity(allocator, 10);

    // Deinit later
    defer gameData.?.deinit();

    try gameData.?.append(5);

    if(gameData) | data |
    {
        try std.testing.expect(data.items.len == 1);
    }
}

test "Deallocating array list of array list"
{
    var list = try std.ArrayList(std.ArrayList(i32)).initCapacity(std.testing.allocator, 5);

    // Does this leak memory?
    try list.append(std.ArrayList(i32).init(std.testing.allocator));

    try list.append(try std.ArrayList(i32).initCapacity(std.testing.allocator, 1));


    // Only need to deinit the items which allocator memory to avoid a memory leak.
    list.items[1].deinit();
    _ = list;

    list.deinit();
}