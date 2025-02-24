const std = @import("std");

const Style = @import("termz").style.Style;
const Cursor = @import("termz").action.Cursor;
const Source = @import("termz").Source;

const getTermSize = @import("termz").action.getTermSize;

pub const Terminal = struct {
    allo: std.mem.Allocator,
    source: std.fs.File,
    buffer: Buffer,

    previous: ?[]Cell = null,

    pub fn init(allo: std.mem.Allocator, source: Source) !@This() {
        // _ = source;
        const cols, const rows = try getTermSize();
        return .{
            .buffer = try Buffer.init(allo, cols, rows),
            .allo = allo,
            // .source = try std.fs.cwd().createFile("test.txt", .{}),
            .source = if (source == .Stdout) std.io.getStdOut() else std.io.getStdErr(),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.source.close();
        if (self.previous) |prev| {
            self.allo.free(prev);
        }
    }

    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        if (self.previous) |prev| {
            for (prev) |cell| {
                cell.deinit(self.allo);
            }
            self.allo.free(prev);
        }
        self.previous = null;
        self.buffer.resize(w, h);
    }

    pub fn render_with_state(self: *@This(), component: anytype, state: anytype) !void {
        // Call render function on component(s)
        const area = Rect { .width = self.buffer.width, .height = self.buffer.height };
        try render_component_with_state(&self.buffer, area, component, state, null);

        // Render buffer iterating previous at the same time
        try self.buffer.render(self.source.writer(), self.previous);

        // Snapshot the buffer cells and store them in the previous frame buffer
        if (self.previous) |prev| {
            for (prev) |*cell| {
                cell.deinit(self.allo);
            }
            self.allo.free(prev);
        }

        self.previous = try self.allo.alloc(Cell, self.buffer.inner.len);
        if (self.previous) |prev| {
            for (0..prev.len) |i| {
                prev[i] = try self.buffer.inner[i].clone(self.allo);
            }
        }
    }

    pub fn render(self: *@This(), component: anytype) !void {
        // Call render function on component(s)
        const area = Rect { .width = self.buffer.width, .height = self.buffer.height };
        try render_component(&self.buffer, area, component, null);

        // Render buffer iterating previous at the same time
        try self.buffer.render(self.source.writer(), self.previous);

        // Snapshot the buffer cells and store them in the previous frame buffer
        if (self.previous) |prev| {
            for (prev) |*cell| {
                cell.deinit(self.allo);
            }
            self.allo.free(prev);
        }

        self.previous = try self.allo.alloc(Cell, self.buffer.inner.len);
        if (self.previous) |prev| {
            for (0..prev.len) |i| {
                prev[i] = try self.buffer.inner[i].clone(self.allo);
            }
        }
    }
};

fn render_component_with_state(buffer: *Buffer, rect: Rect, component: anytype, state: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .Struct => {
            switch (std.meta.fields(T)) {
                .Struct, .Enum => if (@hasDecl(T, "render_with_state")) {
                    try component.render_with_state(buffer, rect, state);
                },
                .Union => |fields| inline for (fields) |field| {
                    try render_component_with_state(buffer, @field(component, field.name), state, style);
                }
            }
        },
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Struct => {
                    if (@hasDecl(p.child, "render_with_state")) {
                        try component.render_with_state(buffer, rect, state);
                    }
                },
                else => {
                    switch (p.child) {
                        []const u8 => try buffer.setSlice(0, 0, component, style),
                        u21, u8, u32, u16, comptime_int => try buffer.set(0, 0, component, style),
                        else => try buffer.setFormatable(0, 0, component, style),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buffer.setSlice(0, 0, component, style),
                u21, u8, u32, u16, comptime_int => try buffer.set(0, 0, component, style),
                else => try buffer.setFormatable(0, 0, component, style),
            }
        }
    }
}

fn render_component(buffer: *Buffer, rect: Rect, component: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .Struct => {
            switch (std.meta.fields(T)) {
                .Struct, .Enum => if (@hasDecl(T, "render")) {
                    try component.render(buffer, rect);
                },
                .Union => |fields| inline for (fields) |field| {
                    try render_component(buffer, @field(component, field.name), style);
                }
            }
        },
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Struct => {
                    if (@hasDecl(p.child, "render")) {
                        try component.render(buffer, rect);
                    }
                },
                else => {
                    switch (p.child) {
                        []const u8 => try buffer.setSlice(0, 0, component, style),
                        u21, u8, u32, u16, comptime_int => try buffer.set(0, 0, component, style),
                        else => try buffer.setFormatable(0, 0, component, style),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buffer.setSlice(0, 0, component, style),
                u21, u8, u32, u16, comptime_int => try buffer.set(0, 0, component, style),
                else => try buffer.setFormatable(0, 0, component, style),
            }
        }
    }
}

pub fn Styled(T: type) type {
    return struct{
        value: T,
        style: Style,

        pub fn init(value: T, style: Style) @This() {
            return .{ .value = value, .style = style };
        }

        pub fn render(self: *@This(), buffer: *Buffer, rect: Rect) !void {
            render_component(buffer, rect, self.value, self.style);
        }
    };
}

pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,
};

pub const Cell = struct {
    symbol: ?[]const u8 = null,
    style: ?Style = null,

    pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
        if (self.symbol) |symbol| {
            alloc.free(symbol);
        }
    }

    pub fn eql(self: *const @This(), other: *const @This()) bool {
        if (!std.meta.eql(self.style, other.style)) return false;
        if (self.symbol != null and other.symbol != null) return std.mem.eql(u8, self.symbol.?, other.symbol.?);
        return self.symbol == null and self.symbol == null;
    }

    pub fn clone(self: *@This(), alloc: std.mem.Allocator) !@This() {
        var s: ?[]u8 = null;
        if (self.symbol) |symbol| {
            s = try alloc.dupe(u8, symbol);
        }
        return .{
            .symbol = s,
            .style = self.style,
        };
    }

    pub fn print(self: @This(), writer: anytype) !void {
        if (self.symbol) |symbol| {
            try writer.print("{s}", .{symbol});
        } else {
            try writer.writeByte(' ');
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
            u8 => {
                if (item.symbol) |symbol| self.alloc.free(symbol);
                var buffer = try self.alloc.alloc(u8, 1);
                buffer[0] = char;
                item.symbol = buffer;
            },
            u16 => {
                var buffer = std.ArrayList(u8).init(self.alloc);
                var it = std.unicode.Utf16LeIterator.init([1]u16{ char });
                while (try it.nextCodepoint()) |cp| {
                    var buff: [4]u8 = undefined;
                    const length = try std.unicode.utf8Encode(cp, &buff);
                    try buffer.appendSlice(buff[0..length]);
                }

                if (item.symbol) |*symbol| self.alloc.free(symbol);
                item.symbol = try buffer.toOwnedSlice();
            },
            u21, u32, comptime_int => {
                var buffer = std.ArrayList(u8).init(self.alloc);

                var buff: [4]u8 = [_]u8{0}**4;
                const length = try std.unicode.utf8Encode(@intCast(char), &buff);
                try buffer.appendSlice(buff[0..length]);

                if (item.symbol) |symbol| self.alloc.free(symbol);
                item.symbol = try buffer.toOwnedSlice();
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
