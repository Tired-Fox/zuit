const widget = @import("../widget.zig");

const root = @import("../root.zig");
const termz = @import("termz");

const Style = termz.style.Style;

const Rect = root.Rect;
const Buffer = root.buffer.Buffer;

const Borders = widget.Borders;
const Padding = widget.Padding;
const Set = widget.Set;
const BorderType = widget.BorderType;

titles: struct {
    top_left: ?[]const u8 = null,
    top_center: ?[]const u8 = null,
    top_right: ?[]const u8 = null,
    bottom_left: ?[]const u8 = null,
    bottom_center: ?[]const u8 = null,
    bottom_right: ?[]const u8 = null,
} = .{},
title_pos: enum { TopLeft, TopCenter, TopRight, BottomLeft, BottomCenter, BottomRight } = .TopLeft,
borders: Borders = .{},
set: Set = Set.SINGLE,
padding: Padding = .{},

border_style: ?Style = null,
style: ?Style = null,

/// Get the inner area of the block after applying the border and the padding
pub fn inner(self: *const @This(), area: Rect) Rect {
    return Rect {
        .x = area.x +| self.padding.left +| self.borders.padding_left(),
        .y = area.y +| self.padding.top +| self.borders.padding_top(),
        .width = area.width -| self.padding.left -| self.padding.right -| self.borders.padding_x(),
        .height = area.height -| self.padding.top -| self.padding.bottom -| self.borders.padding_y(),
    };
}

/// Render the blocks border with it's given style
///
/// Also render the background styling if it is provided
pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
    if (self.borders.top) {
        // Top Left corner
        try buffer.set(area.x, area.y, if (self.borders.left) self.set.top_left else self.set.top, self.border_style);
        // Top Edge
        try buffer.setRepeatX(area.x +| 1, area.y, area.width-|2, self.set.top, self.border_style);
        // Top Right corner
        try buffer.set(area.x + area.width-|1, area.y, if (self.borders.left) self.set.top_right else self.set.top, self.border_style);
    } else if (self.style) |style| {
        // Fill background styling if no top border
        try buffer.setRepeatX(area.x, area.y, area.width-|1, ' ', style);
    }

    if (self.borders.left or self.borders.right) {
        for (1..area.height-1) |i| {
            // Left Edge
            if (self.borders.left) try buffer.set(area.x, area.y + @as(u16, @intCast(i)), self.set.left, self.border_style);
            // Fill background styling
            if (self.style) |style| try buffer.setRepeatX(area.x +| 1, area.y + @as(u16, @intCast(i)), area.width-|2, ' ', style);
            // Right Edge
            if (self.borders.right) try buffer.set(area.x + area.width-|1, area.y + @as(u16, @intCast(i)), self.set.right, self.border_style);
        }
    } else if (self.style) |style| {
        for (1..area.height-|1) |i| {
            // Fill background styling
            try buffer.setRepeatX(area.x, @intCast(i), area.width-|1, ' ', style);
        }
    }

    if (self.borders.bottom) {
        try buffer.set(area.x, area.y + area.height-|1, if (self.borders.left) self.set.bottom_left else self.set.bottom, self.border_style);
        try buffer.setRepeatX(area.x +| 1, area.y + area.height-|1, area.width-|2, self.set.bottom, self.border_style);
        try buffer.set(area.x + area.width-|1, area.y + area.height-|1, if (self.borders.left) self.set.bottom_right else self.set.bottom, self.border_style);
    } else if (self.style) |style| {
        try buffer.setRepeatX(area.x, area.y + area.height-|1, area.width-|1, ' ', style);
    }

    if (self.borders.top) {
        if (self.titles.top_left) |title| {
            const x = self.borders.padding_left();
            try buffer.setSlice(x, 0, title[0..@min(title.len, area.width -| 1)], self.border_style);
        }
        if (self.titles.top_center) |title| {
            const x = @divFloor(area.width -| self.borders.padding_x(), 2) -| @divFloor(@as(u16, @intCast(title.len)), 2);
            try buffer.setSlice(x, 0, title[0..@min(title.len, area.width -| 1)], self.border_style);
        }
        if (self.titles.top_right) |title| {
            const x = area.width -| self.borders.padding_right() -| @as(u16, @intCast(title.len));
            try buffer.setSlice(x, 0, title[0..@min(title.len, area.width -| 1)], self.border_style);
        }
    }

    if (self.borders.bottom) {
        if (self.titles.bottom_left) |title| {
            const x = self.borders.padding_left();
            const y = area.y + area.height -| 1;
            try buffer.setSlice(x, y, title[0..@min(title.len, area.width -| 1)], self.border_style);
        }
        if (self.titles.bottom_center) |title| {
            const x = @divFloor(area.width -| self.borders.padding_x(), 2) -| @divFloor(@as(u16, @intCast(title.len)), 2);
            const y = area.y + area.height -| 1;
            try buffer.setSlice(x, y, title[0..@min(title.len, area.width -| 1)], self.border_style);
        }
        if (self.titles.bottom_right) |title| {
            const x = area.width -| self.borders.padding_right() -| @as(u16, @intCast(title.len));
            const y = area.y + area.height -| 1;
            try buffer.setSlice(x, y, title[0..@min(title.len, area.width -| 1)], self.border_style);
        }
    }
}
