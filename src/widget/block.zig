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

borders: Borders = .{},
set: Set = Set.SINGLE,
padding: Padding = .{},

border_style: ?Style = null,
style: ?Style = null,

/// Get the inner area of the block after applying the border and the padding
pub fn inner(self: *const @This(), rect: Rect) Rect {
    return Rect {
        .x = rect.x +| self.padding.left +| self.borders.padding_left(),
        .y = rect.y +| self.padding.top +| self.borders.padding_top(),
        .width = rect.width -| self.padding.left -| self.padding.right -| self.borders.padding_x(),
        .height = rect.height -| self.padding.top -| self.padding.bottom -| self.borders.padding_y(),
    };
}

/// Render the blocks border with it's given style
///
/// Also render the background styling if it is provided
pub fn render(self: *const @This(), buffer: *Buffer, rect: Rect) !void {
    if (self.borders.top) {
        // Top Left corner
        try buffer.set(rect.x, rect.y, self.set.top_left, self.border_style);
        // Top Edge
        try buffer.setRepeatX(rect.x +| 1, rect.y, rect.width-|2, self.set.top, self.border_style);
        // Top Right corner
        try buffer.set(rect.x + rect.width-|1, rect.y, self.set.top_right, self.border_style);
    } else if (self.style) |style| {
        // Fill background styling if no top border
        try buffer.setRepeatX(rect.x, rect.y, rect.width-|1, ' ', style);
    }

    if (self.borders.left or self.borders.right) {
        for (1..rect.height-1) |i| {
            // Left Edge
            if (self.borders.left) try buffer.set(rect.x, rect.y + @as(u16, @intCast(i)), self.set.left, self.border_style);
            // Fill background styling
            if (self.style) |style| try buffer.setRepeatX(rect.x +| 1, rect.y + @as(u16, @intCast(i)), rect.width-|2, ' ', style);
            // Right Edge
            if (self.borders.right) try buffer.set(rect.x + rect.width-|1, rect.y + @as(u16, @intCast(i)), self.set.right, self.border_style);
        }
    } else if (self.style) |style| {
        for (1..rect.height-|1) |i| {
            // Fill background styling
            try buffer.setRepeatX(rect.x, @intCast(i), rect.width-|1, ' ', style);
        }
    }

    if (self.borders.bottom) {
        try buffer.set(rect.x, rect.y + rect.height-|1, self.set.bottom_left, self.border_style);
        try buffer.setRepeatX(rect.x +| 1, rect.y + rect.height-|1, rect.width-|2, self.set.bottom, self.border_style);
        try buffer.set(rect.x + rect.width-|1, rect.y + rect.height-|1, self.set.bottom_right, self.border_style);
    } else if (self.style) |style| {
        try buffer.setRepeatX(rect.x, rect.y + rect.height-|1, rect.width-|1, ' ', style);
    }
}
