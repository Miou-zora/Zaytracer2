const std = @import("std");

const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");

const ConfigProxy = struct {
    camera: Camera,
};

pub const Config = struct {
    const Self = @This();

    camera: Camera,

    pub fn fromFilePath(path: []const u8, allocator: std.mem.Allocator) !Self {
        // TODO: Check if there is a better way to do that
        // Cause right now it looks a little bit silly :3
        const data = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
        defer allocator.free(data);
        return fromSlice(data, allocator);
    }

    fn fromSlice(data: []const u8, allocator: std.mem.Allocator) !Self {
        const proxy = try std.json.parseFromSliceLeaky(ConfigProxy, allocator, data, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        });
        return .{
            .camera = proxy.camera,
        };
    }
};
