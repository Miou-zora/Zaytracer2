const std = @import("std");
const Vec3 = @import("Vec3.zig").Vec3;
const Pt3 = @import("Pt3.zig").Pt3;
const Ray = @import("Ray.zig");
const Camera = @import("Camera.zig");
const qoi = @import("qoi");
const Light = @import("Light.zig");
const AmbientLight = @import("AmbientLight.zig");
const HitRecord = @import("HitRecord.zig");
const Scene = @import("Scene.zig");
const ColorRGB = @import("ColorRGB.zig").ColorRGB;
const Material = @import("Material.zig");
const Config = @import("Config.zig").Config;
const zmath = @import("zmath");

const EPSILON: f32 = 0.00001;

pub fn compute_lighting(intersection: Vec3, normal: Vec3, scene: *Scene, ray: *const Ray, material: Material) ColorRGB {
    var lighting: ColorRGB = zmath.f32x4(0, 0, 0, 255);
    for (scene.lights.items) |light| {
        switch (light) {
            .point_light => |item| {
                const L = zmath.normalize3(item.position - intersection);
                const new_ray = Ray{
                    .direction = L,
                    .origin = zmath.mulAdd(@as(Vec3, @splat(EPSILON)), normal, intersection),
                };
                const closest_hit = find_closest_intersection(scene, &new_ray, EPSILON, zmath.length3(item.position - intersection)[0]);
                if (closest_hit != null) {
                    continue;
                }
                const n_dot_l = zmath.dot3(normal, L);
                const em = (n_dot_l / (zmath.length3(normal) * zmath.length3(L))) * @as(Vec3, @splat(item.intensity)); // TODO: store item intensity cleanly
                if (em[0] < 0) {
                    continue;
                }
                lighting += item.color * em;
                if (material.specular != -1) {
                    const R = reflect(L, normal);
                    const V = zmath.normalize3(-ray.direction);
                    const r_dot_v = zmath.dot3(R, V);
                    if (r_dot_v[0] > 0) {
                        const i = @as(Vec3, @splat(item.intensity * std.math.pow(f32, r_dot_v[0] / (zmath.length3(R)[0] * zmath.length3(V)[0]), material.specular)));
                        lighting += item.color * i;
                    }
                }
            },
            .ambient_light => |item| {
                lighting += item.color * @as(Vec3, @splat(item.intensity));
            },
        }
    }
    return zmath.clampFast(lighting, @as(ColorRGB, @splat(0)), @as(ColorRGB, @splat(255)));
}

fn find_closest_intersection(scene: *Scene, ray: *const Ray, t_min: f32, t_max: f32) ?HitRecord {
    var closest_hit: ?HitRecord = null;
    for (scene.objects.items) |object|
        object.hits(ray, &closest_hit, t_min, t_max);
    return closest_hit;
}

fn reflect(v: Vec3, n: Vec3) Vec3 {
    return zmath.mulAdd(n * @as(Vec3, @splat(2)), zmath.dot3(v, n), -v);
}

fn get_pixel_color(ray: *const Ray, scene: *Scene, height: u32, width: u32, recursion_depth: usize) ColorRGB {
    const closest_hit_opt = find_closest_intersection(scene, ray, std.math.floatMin(f32), std.math.floatMax(f32));

    if (closest_hit_opt == null) {
        return zmath.f32x4s(0);
    }
    const closest_hit = closest_hit_opt.?;
    const norm = zmath.normalize3(closest_hit.normal);
    const inter = closest_hit.intersection_point;
    const material = closest_hit.material;
    const light_color = compute_lighting(inter, norm, scene, ray, material);
    const color = material.color * light_color / @as(zmath.Vec, @splat(255));
    const reflective = closest_hit.material.reflective;
    if (recursion_depth <= 0 or reflective <= 0) {
        return color;
    }

    const R = reflect(-ray.direction, norm);
    const new_origin = zmath.mulAdd(@as(Vec3, @splat(EPSILON)), norm, closest_hit.intersection_point);
    const new_ray = Ray{
        .direction = R,
        .origin = new_origin,
    };
    const reflected_color = get_pixel_color(
        &new_ray,
        scene,
        height,
        width,
        recursion_depth - 1,
    );
    return color * @as(Vec3, @splat(1 - reflective)) + reflected_color * @as(Vec3, @splat(reflective));
}

var current_height: std.atomic.Value(u32) = std.atomic.Value(u32).init(0);

fn calculate_image_worker(pixels: []qoi.Color, scene: *Scene, height: u32, width: u32) !void {
    const recursion_depth = 20;
    const samples_per_pixel: u32 = scene.camera.antialiasing_samples;
    var rng = std.Random.Xoshiro256.init(0);
    var rand = rng.random();
    while (true) {
        const y = current_height.fetchAdd(1, .monotonic);
        if (y >= height)
            return;
        for (0..width) |x| {
            var pixel_color: ColorRGB = zmath.f32x4s(0);
            for (0..samples_per_pixel) |_| {
                const random_x: f32 = rand.float(f32);
                const random_y: f32 = rand.float(f32);
                const scaled_x: f32 = (@as(f32, @floatFromInt(x)) + random_x - 0.5) / @as(f32, @floatFromInt(width - 1));
                const scaled_y: f32 = (@as(f32, @floatFromInt((height - 1) - y)) + random_y - 0.5) / @as(f32, @floatFromInt(height - 1));
                const jittered_ray: Ray = scene.camera.createRay(scaled_x, scaled_y);
                pixel_color += get_pixel_color(&jittered_ray, scene, height, width, recursion_depth);
            }
            pixel_color /= @as(Vec3, @splat(@as(f32, @floatFromInt(samples_per_pixel))));
            pixels[x + y * width] = .{
                .r = @as(u8, @intFromFloat(pixel_color[0])),
                .g = @as(u8, @intFromFloat(pixel_color[1])),
                .b = @as(u8, @intFromFloat(pixel_color[2])),
                .a = 255,
            };
        }
    }
}

fn calculate_image(pixels: []qoi.Color, scene: *Scene, height: u32, width: u32, allocator: std.mem.Allocator) !void {
    const num_threads = try std.Thread.getCpuCount();
    // const num_threads = 1;
    var threads = try allocator.alloc(std.Thread, num_threads);

    for (0..num_threads) |i|
        threads[i] = try std.Thread.spawn(.{ .allocator = allocator }, calculate_image_worker, .{ pixels, scene, height, width });
    for (threads) |thread|
        thread.join();
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const config = try Config.fromFilePath("config.json", allocator);

    var scene = Scene.init(allocator, config.camera);
    defer scene.deinit();

    for (config.triangles) |obj| {
        try scene.objects.append(obj);
    }
    for (config.lights) |obj| {
        try scene.lights.append(obj);
    }

    const height: u32 = config.camera.height;
    const width: u32 = config.camera.width;

    var image = qoi.Image{
        .width = width,
        .height = height,
        .colorspace = .sRGB,
        .pixels = try allocator.alloc(qoi.Color, width * height),
    };
    defer image.deinit(allocator);

    try calculate_image(image.pixels, &scene, height, width, allocator);

    var file = try std.fs.cwd().createFile("out.qoi", .{});
    defer file.close();

    const buffer = try qoi.encodeBuffer(allocator, image.asConst());
    defer allocator.free(buffer);
    try file.writeAll(buffer);
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
