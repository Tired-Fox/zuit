const std = @import("std");
const termz = @import("termz");

const Style = termz.style.Style;
const Cursor = termz.action.Cursor;

const Rect = @import("./root.zig").Rect;

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

    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        self.alloc.free(self.inner);
        self.inner = try self.alloc.alloc(Cell, @intCast(w * h));
        for (self.inner) |*cell| cell.* = .{};
        self.area.width = w;
        self.area.height = h;
    }

    pub fn set(self: *@This(), x: u16, y: u16, char: anytype, style: ?Style) !void {
        const pos: usize = @intCast((y * self.area.width) + x);
        if (pos >= self.inner.len) return error.OutOfBounds;

        var item = &self.inner[pos];

        switch (@TypeOf(char)) {
            u8 => item.symbol = [4]u8{ char, 0, 0, 0 },
            u21, u32, comptime_int => {
                var buff: [4]u8 = [_]u8{0}**4;
                _ = try std.unicode.utf8Encode(@intCast(char), &buff);
                item.symbol = buff;
            },
            else => @compileError("type not supported as a buffer cell")
        }

        if (style) |s| {
            item.style = s;
        }
    }

    pub fn fill(self: *@This(), area: Rect, char: anytype, style: ?Style) !void {
        for (area.x..area.x+area.width) |w| {
            for (area.y..area.y+area.height) |h| {
                try self.set(@intCast(w), @intCast(h), char, style);
            }
        }
    }

    const WriterContext = struct {
        buffer: *Buffer,
        area: Rect,
        style: ?Style,
    };

    const Writer = std.io.Writer(
        *WriterContext,
        anyerror,
        appendWrite
    );

    fn appendWrite(ctx: *WriterContext, data: []const u8) !usize {
        if (ctx.area.x + data.len > ctx.area.x + ctx.area.width) {
            return error.EndOfBuffer;
        }

        for (data, 0..) |c, i| {
            try ctx.buffer.set(ctx.area.x + @as(u16, @intCast(i)), ctx.area.y, c, ctx.style);
        }

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

    pub fn setSlice(self: *@This(), x: u16, y: u16, slice: []const u8, style: ?Style) !void {
        for (0..slice.len) |i| {
            try self.set(x + @as(u16, @intCast(i)), y, slice[i], style);
        }
    }

    pub fn setRepeatX(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) !void {
        for (0..count) |i| {
            try self.set(x + @as(u16, @intCast(i)), y, char, style);
        }
    }

    pub fn setRepeatY(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) !void {
        for (0..count) |i| {
            try self.set(x, y + @as(u16, @intCast(i)), char, style);
        }
    }

    pub fn get(self: *const @This(), x: u16, y: u16) ?*const Cell {
        const pos: usize = @intCast((y * self.area.width) + x);
        if (pos >= self.inner.len) return null;

        return &self.inner[pos];
    }

    pub fn render(self: *const @This(), writer: anytype, previous: []Cell) !void {
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
            }

            if (h < self.area.height-1 and !jump) {
                try output.print("\r\n", .{});
            }
        }

        if (style) |s| try output.print("{s}", .{ s.reset() });

        try buffer.flush();
    }
};
