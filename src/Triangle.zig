const zmath = @import("zmath");
const Vec = zmath.Vec;

const Ray = @import("Ray.zig");
const HitRecord = @import("HitRecord.zig");

const Self = @This();

va: Vec,
vb: Vec,
vc: Vec,
normal: Vec = undefined,

pub fn hits(self: *const Self, ray: *const Ray, record: *?HitRecord, t_min: f32, t_max: f32) void {
    const a = self.va;
    const b = self.vb;
    const c = self.vc;
    const bSuba = b - a;
    const cSubb = c - b;
    const aSubc = a - c;

    const normal = self.normal;
    const reversed_normal = -normal;
    const t = zmath.dot3(normal, (a - ray.origin)) / zmath.dot3(normal, ray.direction);

    const dist = t[0];
    if (dist < 0) {
        return;
    }

    if (!((record.* == null or dist < record.*.?.t) and dist > t_min and dist < t_max))
        return;

    const hit_point = zmath.mulAdd(ray.direction, t, ray.origin);

    const u = zmath.dot3(zmath.cross3(bSuba, hit_point - a), normal)[0];
    if (u < 0) return;
    const v = zmath.dot3(zmath.cross3(cSubb, hit_point - b), normal)[0];
    if (v < 0) return;
    const w = zmath.dot3(zmath.cross3(aSubc, hit_point - c), normal)[0];
    if (w < 0) return;

    record.* = .{
        .t = dist,
        .intersection_point = hit_point,
        .normal = reversed_normal,
    };
}

pub fn pre_calc_normal(self: *Self) void {
    const a = self.va;
    const b = self.vb;
    const c = self.vc;
    const bSuba = b - a;
    const cSuba = c - a;

    self.normal = zmath.normalize3(zmath.cross3(bSuba, cSuba));
}

pub fn transpose(self: *Self, offset: Vec) void {
    self.va += offset;
    self.vb += offset;
    self.vc += offset;
}
