const std = @import("std");
const Rect = @import("../root.zig").Rect;

pub fn Layout(comptime N: usize) type {
    const U = struct {
        pub const LENGTH: usize = N;

        constraints: [N]Constraint,
        direction: Direction,

        pub fn horizontal(constraints: anytype) @This() {
            var values: [N]Constraint = undefined;
            inline for (constraints, 0..) |constraint, i| values[i] = constraint;
            return .{
                .direction = .Horizontal,
                .constraints = values,
            };
        }

        pub fn vertical(constraints: anytype) @This() {
            var values: [N]Constraint = undefined;
            inline for (constraints, 0..) |constraint, i| values[i] = constraint;
            return .{
                .direction = .Vertical,
                .constraints = values,
            };
        }

        fn cmpConstraint(context: *const [N]Constraint, a: usize, b: usize) bool {
            const tag_a = std.meta.activeTag(context[a]);
            const tag_b = std.meta.activeTag(context[b]);

            if (tag_b == .max and tag_a != .max) return true;
            if (tag_b == .min and tag_a != .max and tag_a != .min) return true;
            if (tag_b == .fill and tag_a != .max and tag_a != .min and tag_a != .fill) return true;

            return false;
        }

        pub fn split(self: *const @This(), area: Rect) [N]Rect {
            const size: u16 = switch (self.direction) {
                .Horizontal => area.width,
                .Vertical => area.height,
            };

            var remaining: u16 = @intCast(size);
            var sizes = [_]u16{ 0 } ** N;
            var indexes = [_]usize { 0 } ** N;

            var total_fill: u16 = 0;
            for (self.constraints, 0..) |constraint, i| {
                indexes[i] = i;
                switch (constraint) {
                    .length => |length| {
                        sizes[i] = if (remaining -| length == 0) remaining else length;
                        remaining -|= length;
                    },
                    .ratio => |ratio| {
                        const numerator: f32 = @floatFromInt(ratio[0]);
                        const denominator: f32 = @floatFromInt(ratio[1]);

                        const w: u16 = @intFromFloat((@as(f32, @floatFromInt(size)) / denominator) * numerator);
                        sizes[i] = if (remaining -| w == 0) remaining else w;
                        remaining -|= w;
                    },
                    .percentage => |p| {
                        const percent: f32 = @divFloor(@as(f32, @floatFromInt(p)), 100.0);
                        const w: u16 = @intFromFloat(@as(f32, @floatFromInt(size)) * percent);

                        sizes[i] = if (remaining -| w == 0) remaining else w;
                        remaining -|= w;
                    },
                    .min => |min| {
                        sizes[i] = if (remaining -| min == 0) remaining else min;
                        remaining -|= min;
                        total_fill +|= 1;
                    },
                    // Leave max and fill at `0` since they only fill remaining space
                    .fill => |fill| total_fill +|= fill,
                    else => {}
                }
            }

            if (remaining > 0 and total_fill > 0) {
                std.mem.sort(usize, &indexes, &self.constraints, cmpConstraint);

                var per = @divFloor(remaining, total_fill);

                for (self.constraints, 0..) |constraint, i| {
                    switch (constraint) {
                        .max => |max| {
                            // Max will fill entire space up to max
                            sizes[i] = if (remaining -| max == 0) remaining else max;
                            remaining -|= max;
                            per = @divFloor(remaining, total_fill);
                        },
                        .min => |min| if (min < per) {
                            sizes[i] = per;
                            remaining -|= per;
                        },
                        .fill => |fill| {
                            if (per == 0) {
                                sizes[i] = if (remaining > 0) 1 else 0; 
                                remaining -|= 1;
                            } else {
                                sizes[i] = per * fill;
                            }
                        },
                        else => {}
                    }
                }
            }

            var areas: [N]Rect = undefined;
            var last: Rect = Rect { .x = area.x, .y = area.y };
            for (sizes, 0..) |s, i| {
                switch (self.direction) {
                    .Horizontal => areas[i] = Rect { .x = last.x + last.width, .y = last.y, .width = s, .height = area.height },
                    .Vertical => areas[i] = Rect { .x = last.x, .y = last.y + last.height, .height = s, .width = area.width },
                }
                last = areas[i];
            }
            return areas;
        }
    };

    return U;
}

pub const Direction = enum {
    Horizontal,
    Vertical,
};

pub const Constraint = union(enum) {
    /// Fixed length
    ///
    /// If this constraint resolves last it will fill the remaining
    /// space with a max of the provided length as to not overflow.
    length: u16,
    /// Acts similar to percentage
    ratio: Ratio,
    /// Clamp from 0 to 100
    percentage: u16,
    /// Minimum size
    ///
    /// Will grow if there is additional remaining space
    min: u16,
    /// Max size
    ///
    /// Will grow if there is additional size, and will
    /// shrink to allow fixed sized or higher priority
    /// constraints to have their desired size.
    max: u16,
    /// Fill remaining space
    ///
    /// This will fill the remaining space with no minimum
    /// or maximum.
    /// 
    /// This is grow to fill empty space and shrink to allow
    /// other higher priority constraints to have their desired size.
    fill: u16,

    pub const Ratio = std.meta.Tuple(&[_]type{ u16, u16 });

    pub fn length(size: u16) @This() {
        return .{ .length = size };
    }

    pub fn ratio(w: u16, h: u16) @This() {
        return .{ .ratio = .{ w, h } };
    }

    pub fn percentage(percent: u16) @This() {
        return .{ .percentage = percent };
    }

    pub fn min(size: u16) @This() {
        return .{ .min = size };
    }

    pub fn max(size: u16) @This() {
        return .{ .max = size };
    }

    pub fn fill(size: u16) @This() {
        return .{ .fill = size };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .length => |value| try writer.print("Length({d})", .{value}),
            .ratio => |value| try writer.print("Ratio({d}, {d})", .{value[0], value[1]}),
            .percentage => |value| try writer.print("Percentage({d})", .{value}),
            .min => |value| try writer.print("Min({d})", .{value}),
            .max => |value| try writer.print("Max({d})", .{value}),
            .fill => |value| try writer.print("Fill({d})", .{value}),
        }
    }
};
