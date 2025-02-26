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

titles: ?[]const widget.Title = null,
title_pos: enum { TopLeft, TopCenter, TopRight, BottomLeft, BottomCenter, BottomRight } = .TopLeft,
borders: Borders = .{},
set: Set = Set.SINGLE,
padding: Padding = .{},

border_style: ?Style = null,
style: ?Style = null,

/// Construct a block with all borders
pub fn bordered() @This() {
    return .{ .borders = Borders.all() };
}

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
    if (area.height == 0 or area.width == 0) return;

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

    if (area.height >= 2 and (self.borders.left or self.borders.right)) {
        for (1..area.height-|1) |i| {
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

    if (self.titles) |titles| {
        const title_area = area.padded(.{ .left = self.borders.padding_left(), .right = self.borders.padding_right() });
        for (titles) |title| {
            if (title.top() and self.borders.top) try title.render(buffer, title_area);
            if (title.bottom() and self.borders.bottom) try title.render(buffer, title_area);
        }
    }
}
