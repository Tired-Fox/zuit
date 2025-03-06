const std = @import("std");
pub const zerm = @import("zerm");
pub const symbols = @import("../symbols.zig");
pub const root = @import("../root.zig");

pub const Buffer = root.Buffer;
pub const Rect = root.Rect;
pub const Style = zerm.style.Style;

pub const Set = symbols.line.Set;

pub const Gauge = struct {
    /// Value from 0.0 to 1.0 representing the progress
    /// out of 100%
    progress: f32,

    label: ?[]const u8 = null,

    filled_style: ?Style = null,
    unfilled_style: ?Style = null,

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.width == 0 or area.height == 0) return;
        // Fill entire area and center the label in the middle
        const remaining = area.width;
        var filled: u16 = @intFromFloat(@ceil(@as(f32, @floatFromInt(remaining)) * self.progress));
        filled = @min(remaining, filled);

        buffer.fill(Rect {
            .x = area.x,
            .y = area.y,
            .width = filled,
            .height = area.height
        }, ' ', self.filled_style);

        buffer.fill(Rect {
            .x = @min(area.x +| filled, area.x +| area.width),
            .y = area.y,
            .width = remaining -| filled,
            .height = area.height
        }, ' ', self.unfilled_style);

        const y = @divFloor(area.height, 2);
        var x = @divFloor(area.width, 2);

        if (self.label) |label| {
            x -|= @intCast(@divFloor(label.len, 2));
            for (label, 0..) |ch, i| {
                const pos = area.x + x + @as(u16, @intCast(i));
                buffer.set(pos, y, ch, if (pos >= area.x + filled) self.unfilled_style else self.filled_style);
            }
        } else {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();

            const label = try std.fmt.allocPrint(arena.allocator(), "{d}%", .{ @as(usize, @intFromFloat(@min(1.0, self.progress) * 100.0)) });
            x -|= @intCast(@divFloor(label.len, 2));
            for (label, 0..) |ch, i| {
                const pos = area.x + x + @as(u16, @intCast(i));
                buffer.set(pos, y, ch, if (pos >= area.x + filled) self.unfilled_style else self.filled_style);
            }
        }
    }
};

pub const LineGauge = struct {
    /// Value from 0.0 to 1.0 representing the progress
    /// out of 100%
    progress: f32,

    label: ?[]const u8 = null,

    set: Set = symbols.line.NORMAL,

    label_style: ?Style = null,
    filled_style: ?Style = null,
    unfilled_style: ?Style = null,

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.width == 0 or area.height == 0) return;
        // Fill entire line where the label is rendered in front of (to the left) of the line
        const char = self.set.horizontal;

        var w: u16 = 4;
        if (self.label) |label| {
            buffer.setSlice(area.x, area.y, label, self.label_style);
            w = @intCast(label.len);
        } else {
            if (self.progress <= 1.0) {
                try buffer.setFormatted(area.x, area.y, self.label_style, "{d}%", .{ @as(usize, @intFromFloat(@min(1.0, self.progress) * 100.0)) });
            } else {
                try buffer.setFormatted(area.x, area.y, self.label_style, " {d}%", .{ @as(usize, @intFromFloat(self.progress * 100.0)) });
            }
        }

        const remaining = area.width -| w;
        var filled: u16 = @intFromFloat(@ceil(@as(f32, @floatFromInt(remaining)) * self.progress));
        filled = @min(remaining, filled);

        buffer.setRepeatX(area.x + w, area.y, filled, char, self.filled_style);
        buffer.setRepeatX(area.x + w + filled, area.y, remaining -| filled, char, self.unfilled_style);
    }
};
