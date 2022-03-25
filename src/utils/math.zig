pub const IntVector2D = struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn Add(self: IntVector2D, other: IntVector2D) IntVector2D
    {
        return IntVector2D {.x = self.x + other.x, .y = self.y + other.y };
    }
};
