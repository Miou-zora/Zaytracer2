const std = @import("std");

const Rect3 = @import("Rect3.zig");
const Ray = @import("Ray.zig");
const zmath = @import("zmath");
const Vec = zmath.Vec;

const Self = @This();

width: u32,
height: u32,
fov: f32,
antialiasing_samples: u32,

pub fn createRay(self: *const Self, x: f32, y: f32) Ray {
    const aspectRatio = @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(self.width));
    const halfWidth = aspectRatio / 2;
    const TO_RAD = std.math.pi / 180.0;
    const distance = (halfWidth * @sin((180.0 - self.fov / 2 - 90.0) * TO_RAD)) / @sin(self.fov * TO_RAD);
    const screen = Rect3{
        .origin = zmath.f32x4(-0.5, -halfWidth, distance, 0),
        .left = zmath.f32x4(1, 0, 0, 0),
        .top = zmath.f32x4(0, aspectRatio, 0, 0),
    };
    return Ray{
        .origin = zmath.f32x4s(0),
        .direction = screen.pointAt(x, y) - zmath.f32x4s(0),
    };
}
