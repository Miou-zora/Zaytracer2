const std = @import("std");
const Camera = @import("Camera.zig");
const Material = @import("Material.zig");
const Scene = @import("Scene.zig");
const AmbientLight = @import("AmbientLight.zig");
const PointLight = @import("Light.zig");
const Light = Scene.SceneLight;
const Vertex = @import("Vertex.zig");
const Image = Scene.Image;
const rl = @import("raylib");
const ColorRGB = @import("ColorRGB.zig").ColorRGB;
const Triangle = @import("Triangle.zig");

const Vec3Proxy = struct {
    x: f32,
    y: f32,
    z: f32,
};
const Pt3Proxy = struct {
    x: f32,
    y: f32,
    z: f32,
};

const VertexProxy = struct {
    position: Pt3Proxy,
    texCoord: @Vector(2, f32),
};

const TriangleProxy = struct {
    va: VertexProxy,
    vb: VertexProxy,
    vc: VertexProxy,
    textIdx: usize,
};

const ColorRGBProxy = struct {
    r: f32,
    g: f32,
    b: f32,
};

const AmbientLightProxy = struct {
    color: ColorRGBProxy,
    intensity: f32,
};

const PointLightProxy = struct {
    color: ColorRGBProxy,
    intensity: f32,
    position: Pt3Proxy,
};

const LightProxy = struct {
    ambient: ?AmbientLightProxy = null,
    point: ?PointLightProxy = null,
};

const AssetProxy = struct {
    imageName: [:0]const u8,
};

const MaterialProxy = struct {
    color: ColorRGBProxy,
    specular: f32,
    reflective: f32,
};

const ConfigProxy = struct {
    camera: Camera,
    triangles: []TriangleProxy,
    materials: []MaterialProxy,
    lights: []LightProxy,
    assets: []AssetProxy,
};

fn load_vertex(from: VertexProxy) Vertex {
    return .{
        .position = .{
            from.position.x,
            from.position.y,
            from.position.z,
            1,
        },
        .texCoord = from.texCoord,
    };
}

fn load_material(proxy: MaterialProxy) Material {
    return Material{
        .color = ColorRGB{ proxy.color.r, proxy.color.g, proxy.color.b, 0 },
        .specular = proxy.specular,
        .reflective = proxy.reflective,
    };
}

pub const Config = struct {
    const Self = @This();

    camera: Camera,
    triangles: []Triangle,
    lights: []Light,
    assets: []Image,

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
        var conf = Self{
            .camera = proxy.camera,
            .triangles = try allocator.alloc(Triangle, proxy.triangles.len),
            .lights = try allocator.alloc(Light, proxy.lights.len),
            .assets = try allocator.alloc(Image, proxy.assets.len),
        };
        for (proxy.assets, 0..) |obj, i| {
            const image = try rl.loadImage(obj.imageName);
            conf.assets[i] = Image{
                .rlImage = image,
                .rlColors = try rl.loadImageColors(image),
            };
        }
        for (proxy.triangles, 0..) |obj, i| {
            conf.triangles[i] = .{
                .va = load_vertex(obj.va),
                .vb = load_vertex(obj.vb),
                .vc = load_vertex(obj.vc),
                .text = &conf.assets[obj.textIdx],
            };
            conf.triangles[i].pre_calc_normal();
        }
        for (proxy.lights, 0..) |obj, i| {
            if (obj.point) |item| {
                conf.lights[i] = Light{
                    .point_light = .{
                        .color = .{ item.color.r, item.color.g, item.color.b, 0 },
                        .intensity = item.intensity,
                        .position = .{ item.position.x, item.position.y, item.position.z, 1 },
                    },
                };
            } else if (obj.ambient) |item| {
                conf.lights[i] = Light{
                    .ambient_light = .{
                        .color = .{ item.color.r, item.color.g, item.color.b, 0 },
                        .intensity = item.intensity,
                    },
                };
            } else {
                unreachable;
            }
        }
        return conf;
    }
};
