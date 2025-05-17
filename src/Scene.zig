const Allocator = @import("std").mem.Allocator;

const Camera = @import("Camera.zig");
const obj = @import("obj");

const Self = @This();

camera: Camera,
cube_obj: obj.ObjData,
cube_mtl: obj.MaterialData,
allocator: Allocator,

pub fn init(allocator: Allocator, camera: Camera) !Self {
    return Self{
        .camera = camera,
        .cube_obj = try obj.parseObj(allocator, @embedFile("assets/cube.obj")),
        .cube_mtl = try obj.parseMtl(allocator, @embedFile("assets/cube.mtl")),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.cube_obj.deinit(self.allocator);
    self.cube_mtl.deinit(self.allocator);
}
