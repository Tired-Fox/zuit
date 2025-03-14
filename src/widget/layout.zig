const std = @import("std");
const Rect = @import("../root.zig").Rect;

/// Splits an area into `N` subdivided areas given
/// the provided constraints.
pub fn Layout(comptime N: usize) type {
    const U = struct {
        /// Number of splits
        pub const LENGTH: usize = N;

        constraints: [N]Constraint,
        direction: Direction,

        /// Space between each subdivided area
        ///
        /// This will act like a gap between child widgets
        spacing: u16 = 0,

        /// Apply a horizontal direction to the split given the constraints
        pub fn horizontal(constraints: []const Constraint) @This() {
            var values: [N]Constraint = undefined;
            for (constraints, 0..) |constraint, i| values[i] = constraint;
            return .{
                .direction = .Horizontal,
                .constraints = values,
            };
        }

        /// Apply a vertical direction to the split given the constraints
        pub fn vertical(constraints: []const Constraint) @This() {
            var values: [N]Constraint = undefined;
            for (constraints, 0..) |constraint, i| values[i] = constraint;
            return .{
                .direction = .Vertical,
                .constraints = values,
            };
        }

        /// Apply a horizontal direction to the split given the constraints
        /// and the spacing (gap) between children
        pub fn horizontalWithSpacing(space: u16, constraints: anytype) @This() {
            var values: [N]Constraint = undefined;
            inline for (constraints, 0..) |constraint, i| values[i] = constraint;
            return .{
                .spacing = space,
                .direction = .Horizontal,
                .constraints = values,
            };
        }

        /// Apply a vertical direction to the split given the constraints
        /// and the spacing (gap) between children
        pub fn verticalWithSpacing(space: u16, constraints: []const Constraint) @This() {
            var values: [N]Constraint = undefined;
            for (constraints, 0..) |constraint, i| values[i] = constraint;
            return .{
                .spacing = space,
                .direction = .Vertical,
                .constraints = values,
            };
        }

        fn cmpConstraint(context: *const [N]Constraint, a: usize, b: usize) bool {
            const tag_a = std.meta.activeTag(context[a]);
            const tag_b = std.meta.activeTag(context[b]);

            return switch (tag_a) {
                .max => switch (tag_b) {
                    .max => false,
                    else => true,
                },
                .min => switch (tag_b) {
                    .max, .min => false,
                    else => true,
                },
                .fill => switch (tag_b) {
                    .max, .min, .fill => false,
                    else => true,
                },
                .length => switch (tag_b) {
                    .max, .min, .fill, .length => false,
                    else => true,
                },
                .percentage => switch (tag_b) {
                    .max, .min, .fill, .length, .percentage => false,
                    else => true,
                },
                .ratio => false,
            };
        }

        /// Split the area into a list of subdivided areas
        pub fn split(self: *const @This(), area: Rect) [N]Rect {
            const size: u16 = switch (self.direction) {
                .Horizontal => area.width,
                .Vertical => area.height,
            };

            var remaining: u16 = @intCast(size);
            var sizes = [_]u16{ 0 } ** N;
            var indexes = [_]usize { 0 } ** N;
            var mins: u16 = 0;

            var total_fill: u16 = 0;
            for (self.constraints, 0..) |constraint, i| {
                indexes[i] = i;
                switch (constraint) {
                    .length => |length| {
                        if (i != 0) {
                            remaining -|= self.spacing;
                        }

                        sizes[i] = if (remaining -| length == 0) remaining else length;
                        remaining -|= length;
                    },
                    .ratio => |ratio| {
                        if (i != 0) {
                            remaining -|= self.spacing;
                        }

                        const numerator: f32 = @floatFromInt(ratio[0]);
                        const denominator: f32 = @floatFromInt(ratio[1]);

                        const w: u16 = @intFromFloat((@as(f32, @floatFromInt(size)) / denominator) * numerator);
                        sizes[i] = if (remaining -| w == 0) remaining else w;
                        remaining -|= w;
                    },
                    .percentage => |p| {
                        if (i != 0) {
                            remaining -|= self.spacing;
                        }

                        const percent: f32 = @as(f32, @floatFromInt(@min(p, 100))) / 100.0;
                        const w: u16 = @intFromFloat(@as(f32, @floatFromInt(size)) * percent);

                        sizes[i] = if (remaining -| w == 0) remaining else w;
                        remaining -|= w;
                    },
                    .min => |min| {
                        if (i != 0) {
                            remaining -|= self.spacing;
                        }

                        sizes[i] = if (remaining -| min == 0) remaining else min;
                        remaining -|= min;
                        mins +|= min;
                        total_fill +|= 1;
                    },
                    // Leave max and fill at `0` since they only fill remaining space
                    .fill => |fill| total_fill +|= fill,
                    else => {}
                }
            }

            if (remaining > 0 and total_fill > 0) {
                std.mem.sort(usize, &indexes, &self.constraints, cmpConstraint);

                for (self.constraints, 0..) |constraint, i| {
                    switch (constraint) {
                        .max => |max| {
                            if (i != 0) {
                                remaining -|= self.spacing;
                            }

                            // Max will fill entire space up to max
                            sizes[i] = if (remaining -| max == 0) remaining else max;
                            remaining -|= max;
                        },
                        .min => |min| {
                            const per = @divFloor(remaining + mins, total_fill);
                            if (min >= per) {
                                sizes[i] = min;
                                mins -= min;
                                total_fill -= 1;
                            }
                        },
                        else => {}
                    }
                }

                const per: f32 = @as(f32, @floatFromInt(remaining + mins)) / @as(f32, @floatFromInt(total_fill));

                for (indexes) |i| {
                    const constraint = self.constraints[i];
                    switch (constraint) {
                        .min => |min| {
                            const amount: u16 = @intFromFloat(per);
                            if (min < amount) {
                                sizes[i] = amount;
                                remaining -|= amount - min;
                                mins -= min;
                                total_fill -= 1;

                                if (total_fill == 0) sizes[i] += remaining;
                            }
                        },
                        .fill => |fill| {
                            if (i != 0) {
                                remaining -|= self.spacing;
                            }

                            var amount: u16 = @intFromFloat(@ceil(per * @as(f32, @floatFromInt(fill))));
                            amount = @min(remaining, amount);

                            sizes[i] = amount;
                            remaining -|= amount;
                            total_fill -= 1;
                            if (total_fill == 0) sizes[i] += remaining;
                        },
                        else => {}
                    }
                }
            }

            var areas: [N]Rect = undefined;
            var last: Rect = Rect { .x = area.x, .y = area.y };
            for (sizes, 0..) |s, i| {
                const spacing = if (i != 0) self.spacing else 0;
                switch (self.direction) {
                    .Horizontal => areas[i] = Rect { .x = last.x + last.width + spacing, .y = last.y, .width = s, .height = area.height },
                    .Vertical => areas[i] = Rect { .x = last.x, .y = last.y + last.height + spacing, .height = s, .width = area.width },
                }
                last = areas[i];
            }
            return areas;
        }
    };

    return U;
}

/// Direction of the split
///
/// - `Horizontal`: Left to Right
/// - `Vertical`: Top to Bottom
pub const Direction = enum {
    Horizontal,
    Vertical,
};

/// Limit or restrict and portion of a layout
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

    pub const Ratio = std.meta.Tuple(&.{ u16, u16 });

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
