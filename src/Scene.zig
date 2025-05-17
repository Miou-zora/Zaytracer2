const Camera = @import("Camera.zig");
const Allocator = @import("std").mem.Allocator;

const Self = @This();

camera: Camera,

pub fn init(allocator: Allocator, camera: Camera) Self {
    _ = allocator;
    return Self{
        .camera = camera,
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}
