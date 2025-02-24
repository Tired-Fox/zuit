const std = @import("std");
const termz = @import("termz");

const Style = termz.style.Style;
const Cursor = termz.action.Cursor;

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

    width: u16,
    height: u16,

    pub fn init(alloc: std.mem.Allocator, width: u16, height: u16) !@This() {
        var buff = try alloc.alloc(Cell, @as(usize, @intCast(width)) * @as(usize, @intCast(height)));
        for (0..buff.len) |i| {
            buff[i] = .{};
        }

        return .{
            .inner = buff,
            .alloc = alloc,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: @This()) void {
        for (0..self.inner.len) |i| {
            self.inner[i].deinit(self.alloc);
        }
        self.alloc.free(self.inner);
    }

    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        var buff = try self.alloc.alloc(Cell, @as(usize, @intCast(w)) * @as(usize, @intCast(h)));
        for (0..buff.len) |i| {
            buff[i] = .{};
        }

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const pos = (y * w) + x;
                if (x >= w or y >= h) {
                    self.inner[pos].deinit(self.alloc);
                } else {
                    buff[pos] = self.inner[pos];
                }
            }
        }

        self.alloc.free(self.inner);
        self.inner = buff;
        self.width = w;
        self.height = h;
    }

    pub fn set(self: *@This(), x: u16, y: u16, char: anytype, style: ?Style) !void {
        const pos: usize = @intCast((y * self.width) + x);
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

    pub fn setFormatable(self: *@This(), x: u16, y: u16, item: anytype, style: ?Style) !void {
        const pos: usize = @intCast((y * self.width) + x);
        if (pos >= self.inner.len) return error.OutOfBounds;

        var buffer = std.ArrayList(u8).init(self.alloc);
        defer buffer.deinit();
        try buffer.writer().print("{s}", .{ item });

        try self.setSlice(x, y, buffer.items, style);
    }

    pub fn setFormatted(self: *@This(), x: u16, y: u16, style: ?Style, fmt: []const u8, args: anytype) !void {
        const pos: usize = @intCast((y * self.width) + x);
        if (pos >= self.inner.len) return error.OutOfBounds;

        var buffer = std.ArrayList(u8).init(self.alloc);
        defer buffer.deinit();
        try buffer.writer().print(fmt, args);

        try self.setSlice(x, y, buffer.items, style);
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
        const pos: usize = @intCast((y * self.width) + x);
        if (pos >= self.inner.len) return null;

        return &self.inner[pos];
    }

    pub fn render(self: *const @This(), writer: anytype, previous: ?[]const Cell) !void {
        var buffer = std.io.bufferedWriter(writer);
        var output = buffer.writer();

        var jump = false;
        var style: ?Style = null;
        try output.print("{s}", .{ Cursor { .col = 1, .row = 1 } });
        for (0..self.height) |h| {
            for (0..self.width) |w| {
                const pos: usize = @intCast((h * self.width) + w);
                if (pos >= self.inner.len) break;

                const cell = &self.inner[pos];
                if (previous) |prev| {
                    const old_cell = &prev[pos];
                    if (!cell.eql(old_cell)) {
                        if (jump) {
                            try output.print("{s}", .{ Cursor { .col = @intCast(w + 1), .row = @intCast(h + 1) } });
                            jump = false;
                        }
                        if (!std.meta.eql(cell.style, style)) {
                            if (style) |s| try output.print("{s}", .{ s.reset() });
                            if (cell.style) |s| try output.print("{s}", .{ s });
                            style = cell.style;
                        }
                        try cell.print(output);
                    } else {
                        jump = true;
                    }
                } else {
                    if (!std.meta.eql(cell.style, style)) {
                        if (style) |s| try output.print("{s}", .{ s.reset() });
                        if (cell.style) |s| try output.print("{s}", .{ s });
                        style = cell.style;
                    }
                    try cell.print(output);
                }
            }

            if (h < self.height-1 and !jump) {
                try output.print("\r\n", .{});
            }
        }

        if (style) |s| try output.print("{s}", .{ s.reset() });

        try buffer.flush();
    }
};
