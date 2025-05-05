const Camera = @import("Camera.zig");
const Light = @import("Light.zig");
const AmbientLight = @import("AmbientLight.zig");
const std = @import("std");
const Triangle = @import("Triangle.zig");
const HitRecord = @import("HitRecord.zig");
const Ray = @import("Ray.zig");
const zmath = @import("zmath");
const rl = @import("raylib");

pub const SceneLight = union(enum) {
    point_light: Light,
    ambient_light: AmbientLight,
};

pub const Image = struct {
    rlImage: rl.Image,
    rlColors: []rl.Color,
};

pub const Asset = union(enum) {
    image: Image,
};

const Self = @This();

camera: Camera,
objects: std.ArrayList(Triangle),
lights: std.ArrayList(SceneLight),

pub fn init(allocator: std.mem.Allocator, camera: Camera) Self {
    return Self{
        .camera = camera,
        .objects = std.ArrayList(Triangle).init(allocator),
        .lights = std.ArrayList(SceneLight).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.objects.deinit();
    self.lights.deinit();
}
