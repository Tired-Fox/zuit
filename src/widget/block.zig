const widget = @import("../widget.zig");
const symbols = @import("../symbols.zig");

const root = @import("../root.zig");
const zerm = @import("zerm");

const Style = zerm.style.Style;

const Rect = root.Rect;
const Buffer = root.buffer.Buffer;

const Borders = widget.Borders;
const Padding = widget.Padding;
const Set = symbols.border.Set;
const BorderType = widget.BorderType;

titles: ?[]const widget.Title = null,
borders: Borders = .{},
set: Set = symbols.border.SINGLE,
padding: Padding = .{},

title_style: Style = .{},
border_style: Style = .{},
style: Style = .{},

/// Construct a block with all borders
pub fn bordered() @This() {
    return .{ .borders = .all };
}

/// Get the inner area of the block after applying the border and the padding
pub fn inner(self: *const @This(), area: Rect) Rect {
    return Rect {
        .x = area.x +| self.padding.left +| self.borders.padding_left(),
        .y = area.y +| self.padding.top +| self.borders.padding_top(),
        .width = area.width -| (self.padding.left + self.padding.right + self.borders.padding_x()),
        .height = area.height -| (self.padding.top + self.padding.bottom + self.borders.padding_y()),
    };
}

/// Render the blocks border with it's given style
///
/// Also render the background styling if it is provided
pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
    if (area.height == 0 or area.width == 0) return;

    if (self.borders.top) {
        // Top Left corner
        buffer.set(area.x, area.y, if (self.borders.left) self.set.top_left else self.set.top, self.border_style.merge(&self.style));
        // Top Edge
        buffer.setRepeatX(area.x +| 1, area.y, area.width-|2, self.set.top, self.border_style.merge(&self.style));
        // Top Right corner
        buffer.set(area.x + area.width-|1, area.y, if (self.borders.left) self.set.top_right else self.set.top, self.border_style.merge(&self.style));
    } else {
        // Fill background styling if no top border
        buffer.setRepeatX(area.x, area.y, area.width-|1, ' ', self.style);
    }

    if (area.height >= 2 and (self.borders.left or self.borders.right)) {
        for (1..area.height-|1) |i| {
            // Left Edge
            if (self.borders.left) buffer.set(area.x, area.y + @as(u16, @intCast(i)), self.set.left, self.border_style.merge(&self.style));
            // Fill background styling
            buffer.setRepeatX(area.x +| 1, area.y + @as(u16, @intCast(i)), area.width-|2, ' ', self.style);
            // Right Edge
            if (self.borders.right) buffer.set(area.x + area.width-|1, area.y + @as(u16, @intCast(i)), self.set.right, self.border_style.merge(&self.style));
        }
    } else {
        for (1..area.height-|1) |i| {
            // Fill background styling
            buffer.setRepeatX(area.x, @intCast(i), area.width-|1, ' ', self.style);
        }
    }

    if (self.borders.bottom) {
        buffer.set(area.x, area.y + area.height-|1, if (self.borders.left) self.set.bottom_left else self.set.bottom, self.border_style.merge(&self.style));
        buffer.setRepeatX(area.x +| 1, area.y + area.height-|1, area.width-|2, self.set.bottom, self.border_style.merge(&self.style));
        buffer.set(area.x + area.width-|1, area.y + area.height-|1, if (self.borders.left) self.set.bottom_right else self.set.bottom, self.border_style.merge(&self.style));
    } else {
        buffer.setRepeatX(area.x, area.y + area.height-|1, area.width-|1, ' ', self.style);
    }

    if (self.titles) |titles| {
        const title_area = area.padded(.{ .left = self.borders.padding_left(), .right = self.borders.padding_right() });
        const style = self.title_style.merge(&self.border_style).merge(&self.style);
        for (titles) |title| {
            if (title.top() and self.borders.top) try title.renderWithState(buffer, title_area, .{ .style = style, .method = .merge });
            if (title.bottom() and self.borders.bottom) try title.renderWithState(buffer, title_area, .{ .style = style, .method = .merge });
        }
    }
}
