const std = @import("std");
const termz = @import("termz");
const widgets = @import("../widget.zig");
const root = @import("../root.zig");

const Style = termz.style.Style;

const Buffer = root.Buffer;
const Rect = root.Rect;

const Line = widgets.Line;
const Align = widgets.Align;
const Span = widgets.Span;

pub const List = struct {
    items: []const Line,

    highlight_symbol: []const u8 = ">>",
    highlight_style: ?Style = null,

    style: ?Style = null,

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.height == 0 or area.width == 0) return;

        var pos = area;
        for (self.items) |item| {
            try (Line {
                .spans = item.spans,
                .style = item.style orelse self.style,
                .trim = item.trim,
                .text_align = item.text_align,
            }).render(buffer, pos);
            pos.y += 1;
            if (pos.y > area.y + area.height - 1) break;
        }
    }

    pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: usize) !void {
        if (area.height == 0 or area.width == 0) return;

        const height: usize = @intCast(area.height -| 1);
        const current = @min(state, self.items.len - 1);
        const half = @divFloor(height, 2);

        const left = if (current == self.items.len - 1) height else half;

        const min = current -| left;
        const max = @min(current + (height - (current -| min)) + 1, self.items.len);

        var pos = Rect { .x = area.x + @as(u16, @intCast(self.highlight_symbol.len)) + 1, .y = area.y, .width = area.width, .height = area.height };
        for (self.items[min..current]) |item| {
            try (Line {
                .spans = item.spans,
                .style = item.style orelse self.style,
                .trim = item.trim,
                .text_align = item.text_align,
            }).render(buffer, pos);
            pos.y += 1;
        }

        buffer.setSlice(area.x, pos.y, self.highlight_symbol, self.highlight_style);
        buffer.set(area.x + @as(u16, @intCast(self.highlight_symbol.len)), pos.y, ' ', self.highlight_style);
        if (self.highlight_style) |hs| {
            const item = self.items[current];

            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            var spans = try arena.allocator().alloc(Span, item.spans.len);
            for (item.spans, 0..) |span, i| {
                spans[i] = .{
                    .text = span.text,
                    .style = hs,
                };
            }

            try (Line {
                .spans = spans,
                .text_align = item.text_align,
                .trim = item.trim,
                .style = hs
            }).render(buffer, pos);
        } else {
            try self.items[current].render(buffer, pos);
        }
        pos.y += 1;

        for (self.items[current +| 1..max]) |item| {
            try (Line {
                .spans = item.spans,
                .style = item.style orelse self.style,
                .trim = item.trim,
                .text_align = item.text_align,
            }).render(buffer, pos);
            pos.y += 1;
        }
    }
};
