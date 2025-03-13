const std = @import("std");
const zerm = @import("zerm");

const Style = zerm.style.Style;
const Cursor = zerm.action.Cursor;

const Rect = @import("./root.zig").Rect;
const renderComponent = @import("./root.zig").renderComponent;
const renderComponentWithState = @import("./root.zig").renderComponentWithState;

pub const Cell = struct {
    symbol: ?[4]u8 = null,
    style: ?Style = null,

    pub fn eql(self: *const @This(), other: *const @This()) bool {
        if (!std.meta.eql(self.style, other.style)) return false;
        if (self.symbol != null and other.symbol != null) {
            return std.mem.eql(u8, &self.symbol.?, &other.symbol.?);
        }
        return self.symbol == null and self.symbol == null;
    }

    pub fn print(self: *const @This(), writer: anytype) !void {
        if (self.symbol) |symbol| {
            try writer.print("{s}", .{ symbol });
        } else {
            try writer.print(" ", .{});
        }
    }
};

pub const Buffer = struct {
    alloc: std.mem.Allocator,

    inner: []Cell,

    /// Area that this buffer represents
    area: Rect,

    pub fn init(alloc: std.mem.Allocator, area: Rect) !@This() {
        var buff = try alloc.alloc(Cell, @as(usize, @intCast(area.width * area.height)));
        for (0..buff.len) |i| {
            buff[i] = .{};
        }

        return .{
            .inner = buff,
            .alloc = alloc,
            .area = area,
        };
    }

    pub fn deinit(self: @This()) void {
        self.alloc.free(self.inner);
    }

    pub fn clear(self: *@This()) !void {
        for (self.inner)|*cell| {
            cell.symbol = null;
            cell.style = null;
        }
    }

    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        self.alloc.free(self.inner);
        self.inner = try self.alloc.alloc(Cell, @intCast(w * h));
        for (self.inner) |*cell| cell.* = .{ .symbol = [_]u8 { ' ', 0, 0, 0 }};
        self.area.width = w;
        self.area.height = h;
    }

    pub fn set(self: *@This(), x: u16, y: u16, char: anytype, style: ?Style) void {
        const pos: usize = @intCast((y * self.area.width) + x);
        if (x >= self.area.width or y >= self.area.height or pos >= self.inner.len) return;

        var item = &self.inner[pos];

        switch (@TypeOf(char)) {
            u8 => item.symbol = [4]u8{ char, 0, 0, 0 },
            u21, u32, comptime_int => {
                var buff: [4]u8 = [_]u8{0}**4;
                _ = std.unicode.utf8Encode(@intCast(char), &buff) catch return;
                item.symbol = buff;
            },
            else => @compileError("type cannot be converted to a buffer cell")
        }

        item.style = style;
    }

    pub fn fill(self: *@This(), area: Rect, char: anytype, style: ?Style) void {
        for (area.x..area.x+area.width) |w| {
            for (area.y..area.y+area.height) |h| {
                self.set(@intCast(w), @intCast(h), char, style);
            }
        }
    }

    const WriterContext = struct {
        buffer: *Buffer,
        area: Rect,
        style: ?Style,
    };

    const Writer = std.io.GenericWriter(
        *WriterContext,
        anyerror,
        appendWrite
    );

    fn appendWrite(ctx: *WriterContext, data: []const u8) !usize {
        ctx.buffer.setSlice(ctx.area.x, ctx.area.y, data, ctx.style);
        ctx.area.x +|= @as(u16, @intCast(data.len));
        return data.len;
    }

    pub fn setFormatted(self: *@This(), x: u16, y: u16, style: ?Style, comptime fmt: []const u8, args: anytype) !void {
        const pos: usize = @intCast((y * self.area.width) + x);
        if (pos >= self.inner.len) return error.OutOfBounds;

        var context = WriterContext {
            .buffer = self,
            .area = Rect { .x = x, .y = y, .width = self.area.width, .height = self.area.height },
            .style = style,
        };
        const writer = Writer { .context = &context };

        try writer.print(fmt, args);
    }

    pub fn setSlice(self: *@This(), x: u16, y: u16, slice: []const u8, style: ?Style) void {
        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = slice };
        var i: usize = 0;
        while (iter.nextCodepoint()) |codepoint| : (i += 1) {
            self.set(x + @as(u16, @intCast(i)), y, codepoint, style);
        }
    }

    pub fn setRepeatX(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) void {
        for (0..count) |i| {
            self.set(x + @as(u16, @intCast(i)), y, char, style);
        }
    }

    pub fn setRepeatY(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) void {
        for (0..count) |i| {
            self.set(x, y + @as(u16, @intCast(i)), char, style);
        }
    }

    pub fn get(self: *const @This(), x: u16, y: u16) ?*const Cell {
        const pos: usize = @intCast((y * self.area.width) + x);
        if (x >= self.area.width or y >= self.area.height or pos >= self.inner.len) return null;

        return &self.inner[pos];
    }

    pub fn render(self: *@This(), component: anytype, area: Rect) !void {
        try renderComponent(self.alloc, component, self, area);
    }

    pub fn renderWithState(self: *@This(), component: anytype, area: Rect, state: anytype) !void {
        try renderComponentWithState(self.alloc, component, self, area, state);
    }

    pub fn write(self: *const @This(), writer: anytype, previous: []Cell) !void {
        var buffer = std.io.bufferedWriter(writer);
        var output = buffer.writer();

        var jump = false;
        var style: ?Style = null;

        try output.print("{s}", .{ Cursor { .col = self.area.x, .row = self.area.y } });
        for (0..self.area.height) |h| {
            for (0..self.area.width) |w| {
                const pos: usize = @intCast((h * self.area.width) + w);
                if (pos >= self.inner.len) break;

                const cell = &self.inner[pos];
                const old_cell = &previous[pos];

                if (!cell.eql(old_cell)) {
                    if (jump) {
                        try output.print("{s}", .{ Cursor {
                            .col = self.area.x + @as(u16, @intCast(w + 1)),
                            .row = self.area.y + @as(u16, @intCast(h + 1))
                        }});
                        jump = false;
                    }
                    if (!std.meta.eql(cell.style, style)) {
                        if (style) |s| try output.print("{s}", .{ s.reset() });
                        if (cell.style) |s| try output.print("{s}", .{ s });
                        style = cell.style;
                    }
                    try cell.print(output);
                    previous[pos] = cell.*;
                } else {
                    jump = true;
                }

                self.inner[pos] = .{};
            }

            if (h < self.area.height-1 and !jump) {
                try output.print("\r\n", .{});
            }
        }

        if (style) |s| try output.print("{s}", .{ s.reset() });

        try buffer.flush();
    }
};
