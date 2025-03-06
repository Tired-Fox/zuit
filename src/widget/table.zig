const std = @import("std");
const zerm = @import("zerm");
const widgets = @import("../widget.zig");
const root = @import("../root.zig");

const Style = zerm.style.Style;

const Buffer = root.Buffer;
const Rect = root.Rect;

const Padding = widgets.Padding;
const Line = widgets.Line;
const Constraint = widgets.Constraint;
const Layout = widgets.Layout;
const Align = widgets.Align;
const Span = widgets.Span;

pub const TableState = struct {
    column: ?u16 = null,
    row: u16 = 0,
};

pub fn Row(N: usize) type {
    return struct {
        columns: [N]Line,
        style: Style = .{},
        margin: Margin = .{},

        pub const Margin = struct {
            top: u16 = 0,
            bottom: u16 = 0,

            pub fn init(_top: u16, _bottom: u16) @This() {
                return .{ .top = _top, .bottom = _bottom };
            }

            pub fn symmetric(size: u16) @This() {
                return .{ .top = size, .bottom = size };
            }
        };

        pub fn raw(columns: [N]Line) @This() {
            return .{ .columns = columns };
        }
    };
}

pub fn Table(N: usize) type {
    comptime var default_constraints: [N]Constraint = undefined;
    inline for (0..N) |i| {
        default_constraints[i] = .{ .fill = 1 };
    }

    return struct {
        header: ?Row(N) = null,
        rows: []const Row(N),
        footer: ?Row(N) = null,

        constraints: [N]Constraint = default_constraints,
        spacing: u16 = 0,
        style: Style = .{},

        highlight_symbol: []const u8 = ">> ",
        highlight_spacing: enum { always, never, auto } = .auto,

        row_highlight_style: ?Style = null,
        column_highlight_style: ?Style = null,
        cell_highlight_style: ?Style = null,

        pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
            if (area.height == 0 or area.width == 0) return;


            const layout = Layout(N).horizontalWithSpacing(self.spacing, &self.constraints);
            if (self.header) |header| {
                const style = self.style.merge(&header.style);
                buffer.setRepeatX(area.x, area.y, area.width, ' ', style);
                for (header.columns) |th| {
                    try th.renderWithState(buffer, area, .{ .style = style, .method = .merge });
                }
            }

            var offset: u16 = 0;
            if (self.header) |header| offset +|= header.margin.bottom;
            if (self.footer) |footer| offset +|= footer.margin.top;
            var pos = Rect {
                .x = area.x,
                .y = if (self.header) |header| area.y + 1 + header.margin.bottom else area.y,
                .width = area.width,
                .height = area.height -| offset,
            };
            for (self.rows) |row| {
                pos.y += row.margin.top;
                if (pos.y >= area.y + area.height) break;

                const style = self.style.merge(&row.style);
                const cells = layout.split(pos);
                for (row.columns, cells) |td, cell| {
                    try td.renderWithState(buffer, cell, .{ .style = style });
                }

                pos.y += 1 + row.margin.bottom;
                if (pos.y >= area.y + area.height) break;
            }

            if (self.footer) |footer| {
                const style = self.style.merge(&footer.style);
                buffer.setRepeatX(area.x, area.y + area.height - 1, area.width, ' ', style);
                const f = Rect {
                    .x = area.x,
                    .y = area.y + area.height - 1,
                    .width = area.width,
                    .height = area.height
                };
                for (footer.columns) |th| {
                    try th.renderWithState(buffer, f, .{ .style = style, .method = .merge });
                }
                pos.y += 1;
            }
        }

        pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: *const TableState) !void {
            if (area.height == 0 or area.width == 0) return;

            const layout = Layout(N).horizontalWithSpacing(self.spacing, &self.constraints);
            const hlw = @as(u16, @intCast(self.highlight_symbol.len));

            var offset: u16 = 0;
            if (self.header) |header| offset +|= 1 + header.margin.bottom;
            if (self.footer) |footer| offset +|= 1 + footer.margin.top;

            const height: usize = @intCast(area.height - offset);
            const current = @min(state.row, self.rows.len - 1);
            const half = @divFloor(height, 2);

            const left = if (current == self.rows.len - 1) height else half;

            const min = current -| left;
            const max = @min(current + (height - (current -| min)) + 1, self.rows.len);
            var pos = Rect {
                .x = area.x + hlw,
                .y = if (self.header) |header| area.y + 1 + header.margin.bottom else area.y,
                .width = area.width -| hlw,
                .height = area.height -| offset
            };

            if (state.column != null and self.column_highlight_style != null) {
                const cell = layout.split(Rect {
                    .x = area.x + hlw,
                    .width = area.width -| hlw,
                    .y = area.y,
                    .height = area.height,
                })[@intCast(state.column.?)];
                buffer.fill(cell, ' ', self.column_highlight_style);
            }

            if (self.header) |header| {
                const style = self.style.merge(&header.style);
                buffer.setRepeatX(area.x, area.y, area.width, ' ', style);
                const h = Rect { .x = area.x + hlw, .y = area.y, .width = area.width -| hlw, .height = area.height };
                for (header.columns) |th| {
                    try th.renderWithState(buffer, h, .{ .style = style, .method = .merge });
                }
            }

            for (self.rows[min..current]) |row| {
                pos.y += row.margin.top;
                if (pos.y >= area.y + area.height) break;

                const cells = layout.split(pos);
                const style = self.style.merge(&row.style);
                for (row.columns, cells, 0..) |td, cell, i| {
                    if (state.column != null and state.column.? == @as(u16, @intCast(i)) and self.column_highlight_style != null) {
                        try td.renderWithState(buffer, cell, .{ .style = self.column_highlight_style.?.merge(&style), .method = .override });
                    } else {
                        try td.renderWithState(buffer, cell, .{ .style = style });
                    }
                }

                pos.y += 1 + row.margin.bottom;
                if (pos.y >= area.y + area.height) break;
            }

            current: {
                const row = self.rows[current];
                pos.y += row.margin.top;
                if (pos.y >= area.y + area.height) break :current;

                const cells = layout.split(pos);
                const style = self.style.merge(&self.rows[current].style);

                buffer.setRepeatX(area.x, pos.y, area.width, ' ', if (self.row_highlight_style) |rhl| rhl else style);
                buffer.setSlice(area.x, pos.y, self.highlight_symbol, self.row_highlight_style orelse style);
                for (self.rows[current].columns, cells, 0..) |td, cell, i| {
                    var highlight = self.row_highlight_style;
                    if (state.column != null and state.column.? == @as(u16, @intCast(i)) and self.cell_highlight_style != null) {
                        highlight = self.cell_highlight_style;
                        buffer.setRepeatX(cell.x, cell.y, cell.width, ' ', highlight);
                    }

                    if (highlight) |hl| {
                        try td.renderWithState(buffer, cell, .{ .style = hl.merge(&style), .method = .override });
                    } else {
                        try td.renderWithState(buffer, cell, .{ .style = style });
                    }
                }

                pos.y += 1 + row.margin.bottom;
            }

            for (self.rows[current +| 1..max]) |row| {
                pos.y += row.margin.top;
                if (pos.y >= area.y + area.height) break;

                const cells = layout.split(pos);
                const style = self.style.merge(&row.style);
                for (row.columns, cells, 0..) |td, cell, i| {
                    if (state.column != null and state.column.? == @as(u16, @intCast(i)) and self.column_highlight_style != null) {
                        try td.renderWithState(buffer, cell, .{ .style = self.column_highlight_style.?.merge(&style), .method = .override });
                    } else {
                        try td.renderWithState(buffer, cell, .{ .style = style });
                    }
                }

                pos.y += 1 + row.margin.bottom;
                if (pos.y >= area.y + area.height) break;
            }

            if (self.footer) |footer| {
                const style = self.style.merge(&footer.style);
                buffer.setRepeatX(area.x, area.y + area.height - 1, area.width, ' ', style);
                const f = Rect {
                    .x = area.x + hlw,
                    .y = area.y + area.height - 1,
                    .width = area.width -| hlw,
                    .height = area.height
                };
                for (footer.columns) |th| {
                    try th.renderWithState(buffer, f, .{ .style = style, .method = .merge });
                }
                pos.y += 1;
            }
        }
    };
}
