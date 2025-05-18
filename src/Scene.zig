const std = @import("std");
const Allocator = std.mem.Allocator;

const Vec = @import("zmath").Vec;

const Camera = @import("Camera.zig");
const obj = @import("obj");
const Triangle = @import("Triangle.zig");

const Self = @This();

camera: Camera,
allocator: Allocator,
triangles: std.ArrayListUnmanaged(Triangle),

pub fn init(allocator: Allocator, camera: Camera) !Self {
    return Self{
        .camera = camera,
        .triangles = .{},
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.triangles.deinit(self.allocator);
}

pub fn load_obj(self: *Self, filepath: []const u8, offset: Vec) !void {
    // Read at most 1GB
    // This should be more than enough lmao
    const file_content = try std.fs.cwd().readFileAlloc(self.allocator, filepath, 1 * 1024 * 1024 * 1024);
    defer self.allocator.free(file_content);
    var obj_data = try obj.parseObj(self.allocator, file_content);
    defer obj_data.deinit(self.allocator);

    // std.debug.print("{}\n", .{obj_data);

    for (obj_data.meshes) |mesh| {
        var idx: usize = 0;
        var normal = Vec{ 0, 0, 0, 0 };
        for (0..3) |i|
            normal += Vec{
                obj_data.normals[mesh.indices[idx + i].normal.? * 3],
                obj_data.normals[mesh.indices[idx + i].normal.? * 3 + 1],
                obj_data.normals[mesh.indices[idx + i].normal.? * 3 + 2],
                0,
            };
        normal /= @splat(3);
        while (idx < mesh.indices.len) {
            // std.debug.print("indices: {any}\n", .{mesh.indices[idx .. idx + 3]});
            var tri: Triangle = .{
                .va = .{
                    obj_data.vertices[mesh.indices[idx].vertex.? * 3],
                    obj_data.vertices[mesh.indices[idx].vertex.? * 3 + 1],
                    -obj_data.vertices[mesh.indices[idx].vertex.? * 3 + 2],
                    0,
                },
                .vb = .{
                    obj_data.vertices[mesh.indices[idx + 1].vertex.? * 3],
                    obj_data.vertices[mesh.indices[idx + 1].vertex.? * 3 + 1],
                    -obj_data.vertices[mesh.indices[idx + 1].vertex.? * 3 + 2],
                    0,
                },
                .vc = .{
                    obj_data.vertices[mesh.indices[idx + 2].vertex.? * 3],
                    obj_data.vertices[mesh.indices[idx + 2].vertex.? * 3 + 1],
                    -obj_data.vertices[mesh.indices[idx + 2].vertex.? * 3 + 2],
                    0,
                },
                .normal = normal,
            };
            tri.transpose(offset);
            tri.pre_calc_normal();
            try self.triangles.append(self.allocator, tri);
            idx += 3;
            // return;
        }
    }
    // std.debug.print("triangles: {any}\n", .{self.triangles.items});
}
