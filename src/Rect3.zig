const Vec = @import("zmath").Vec;

const Self = @This();

origin: Vec,
top: Vec,
left: Vec,

pub fn pointAt(self: *const Self, x: f32, y: f32) Vec {
    return self.origin + self.top * @as(Vec, @splat(y)) + self.left * @as(Vec, @splat(x));
}
