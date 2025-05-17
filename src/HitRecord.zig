const Vec = @import("zmath").Vec;

const Self = @This();

hit: bool,
normal: Vec,
intersection_point: Vec,
t: f32,
