const std = @import("std");
const zerm = @import("zerm");
const widgets = @import("../widget.zig");
const root = @import("../root.zig");

const Style = zerm.style.Style;

const Buffer = root.Buffer;
const Rect = root.Rect;

const Line = widgets.Line;
const Align = widgets.Align;
const Span = widgets.Span;

/// A list of styled lines that may be highlighted
pub const List = struct {
    items: []const Line,

    /// Symbol that is used to prefix the highlighted line
    highlight_symbol: []const u8 = ">>",
    /// Override style used on the line that is highlighted
    highlight_style: ?Style = null,

    /// Style to merge with each lines style
    style: ?Style = null,

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.height == 0 or area.width == 0) return;

        var pos = area;
        for (self.items) |item| {
            try item.renderWithState(buffer, pos, .{ .style = self.style });
            pos.y += 1;
            if (pos.y > area.y + area.height - 1) break;
        }
    }

    pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: usize) !void {
        if (area.height == 0 or area.width == 0) return;

        const height: usize = @intCast(area.height -| 1);
        const current = @min(state, self.items.len - 1);
        const half = @divFloor(height, 2);

        const left = if (
            self.items.len <= area.height
            or current == self.items.len - 1
        ) height
        else half;

        const min = current -| left;
        const max = @min(current + (height - (current -| min)) + 1, self.items.len);

        var pos = Rect { .x = area.x + @as(u16, @intCast(self.highlight_symbol.len)) + 1, .y = area.y, .width = area.width, .height = area.height };
        for (self.items[min..current]) |item| {
            try item.renderWithState(buffer, pos, .{ .style = self.style });
            pos.y += 1;
        }

        {
            const item = self.items[current];
            buffer.setSlice(area.x, pos.y, self.highlight_symbol, self.highlight_style);
            buffer.set(area.x + @as(u16, @intCast(self.highlight_symbol.len)), pos.y, ' ', self.highlight_style);
            if (self.highlight_style) |hs| {
                try item.renderWithState(buffer, pos, .{ .style = hs, .method = .override });
            } else {
                try item.render(buffer, pos);
            }
            pos.y += 1;
        }

        for (self.items[current +| 1..max]) |item| {
            try item.renderWithState(buffer, pos, .{ .style = self.style });
            pos.y += 1;
        }
    }
};
