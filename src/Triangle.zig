const Vertex = @import("Vertex.zig");
const Ray = @import("Ray.zig");
const HitRecord = @import("HitRecord.zig");
const Vec3 = @import("Vec3.zig").Vec3;
const Material = @import("Material.zig");
const std = @import("std");
const Image = @import("Scene.zig").Image;
const rl = @import("raylib");
const zmath = @import("zmath");
const Pt3 = @import("Pt3.zig").Pt3;
const ColorRGB = @import("ColorRGB.zig").ColorRGB;

const Self = @This();

va: Vertex,
vb: Vertex,
vc: Vertex,
normal: @Vector(4, f32) = undefined,
text: *const Image,

fn hits(self: *const Self, ray: *const Ray) HitRecord {
    // TODO: add bvh + compute this only one time
    const a = self.va.position;
    const b = self.vb.position;
    const c = self.vc.position;
    const bSuba = b - a;

    const normal = self.normal;
    const t = zmath.dot3(normal, (a - ray.origin)) / zmath.dot3(normal, ray.direction);

    if (t[0] < 0) {
        return HitRecord.nil();
    }

    const hit_point = zmath.mulAdd(ray.direction, t, ray.origin);

    const aSubc = a - c;
    const cSubb = c - b;

    const u = zmath.dot3(zmath.cross3(bSuba, hit_point - a), normal)[0];
    if (u < 0) return HitRecord.nil();
    const v = zmath.dot3(zmath.cross3(cSubb, hit_point - b), normal)[0];
    if (v < 0) return HitRecord.nil();
    const w = zmath.dot3(zmath.cross3(aSubc, hit_point - c), normal)[0];
    if (w < 0) return HitRecord.nil();

    const barycentric = zmath.f32x4(u, v, w, 0);
    const texCoord1 = zmath.f32x4(self.va.texCoord[0], self.vb.texCoord[0], self.vc.texCoord[0], 0); // Is it efficient to store this in tmp const?
    const texCoord2 = zmath.f32x4(self.va.texCoord[1], self.vb.texCoord[1], self.vc.texCoord[1], 0); // same
    const posInImage: @Vector(2, usize) = .{
        @as(usize, @intFromFloat(@reduce(.Add, barycentric * texCoord1) / @reduce(.Add, barycentric) * @as(f32, @floatFromInt(self.text.rlImage.width)))),
        @as(usize, @intFromFloat(@reduce(.Add, barycentric * texCoord2) / @reduce(.Add, barycentric) * @as(f32, @floatFromInt(self.text.rlImage.height)))),
    };
    const cInt_to_usize = @as(usize, @intCast(self.text.rlImage.width));
    const color: rl.Color = self.text.rlColors[@min(posInImage[1] * cInt_to_usize + posInImage[0], self.text.rlColors.len - 1)];
    const colorRGB: ColorRGB = zmath.f32x4(@as(f32, @floatFromInt(color.r)), @as(f32, @floatFromInt(color.g)), @as(f32, @floatFromInt(color.b)), 0);

    return .{
        .hit = true,
        .t = zmath.length3(hit_point - ray.origin)[0],
        .intersection_point = hit_point,
        .normal = normal,
        .material = .{
            .color = colorRGB,
            .reflective = 0,
            .specular = 0,
        },
    };
}

pub fn pre_calc_normal(self: *Self) void {
    const a = self.va.position;
    const b = self.vb.position;
    const c = self.vc.position;
    const bSuba = b - a;
    const cSuba = c - a;

    self.normal = zmath.normalize3(zmath.cross3(bSuba, cSuba));
}

pub fn fetch_closest_object(obj: *const Self, closest_hit: *HitRecord, ray: *const Ray, t_min: f32, t_max: f32) void {
    const record = obj.hits(ray);
    if (record.hit and (!closest_hit.hit or record.t < closest_hit.t) and record.t > t_min and record.t < t_max) {
        closest_hit.* = record;
    }
}
