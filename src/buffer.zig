const std = @import("std");
const zerm = @import("zerm");

const Style = zerm.style.Style;
const Cursor = zerm.action.Cursor;

const Rect = @import("./root.zig").Rect;
const renderComponent = @import("./root.zig").renderComponent;
const renderComponentWithState = @import("./root.zig").renderComponentWithState;

/// Representation of a styled 1 column x 1 row unit
/// in the terminal
pub const Cell = struct {
    symbol: ?[4]u8 = null,
    style: ?Style = null,

    pub fn eql(self: *const @This(), other: *const @This()) bool {
        if (!std.meta.eql(self.style, other.style)) return false;
        if (self.symbol != null and other.symbol != null) {
            return std.mem.eql(u8, &self.symbol.?, &other.symbol.?);
        }
        return false;
    }

    pub fn print(self: *const @This(), writer: anytype) !void {
        if (self.symbol) |symbol| {
            try writer.print("{s}", .{ symbol });
        } else {
            try writer.print(" ", .{});
        }
    }
};

/// A linear representation of each cell
/// in the terminal.
///
/// This strut also contains logic for manipulating
/// and rendering those cells.
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

    /// Resize the buffer and clear each cell of the buffer
    ///
    /// This will reallocate memory as needed for the updated
    /// sizing.
    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        self.alloc.free(self.inner);
        self.inner = try self.alloc.alloc(Cell, @intCast(w * h));
        for (self.inner) |*cell| cell.* = .{};
        self.area.width = w;
        self.area.height = h;
    }

    /// Assign a character and style to a given cell
    pub fn set(self: *@This(), col: u16, row: u16, char: anytype, style: ?Style) void {
        const pos: usize = @intCast((row * self.area.width) + col);
        if (col >= self.area.width or row >= self.area.height or pos >= self.inner.len) return;

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

    /// Clear a cell of the symbol and styling
    pub fn unset(self: *@This(), col: u16, row: u16) void {
        const pos: usize = @intCast((row * self.area.width) + col);
        if (col >= self.area.width or row >= self.area.height or pos >= self.inner.len) return;

        var item = &self.inner[pos];
        item.style = null;
        item.symbol = null;
    }

    /// Fill an area of cells with the same character and styling
    pub fn fill(self: *@This(), area: Rect, char: anytype, style: ?Style) void {
        for (area.x..area.x+area.width) |col| {
            for (area.y..area.y+area.height) |row| {
                self.set(@intCast(col), @intCast(row), char, style);
            }
        }
    }

    /// Clear each cell within the area
    pub fn clear(self: *@This(), area: Rect) void {
        for (0..area.x + area.width) |col| {
            for (0..area.y + area.height) |row| {
                self.unset(@intCast(col), @intCast(row));
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

    /// Format the given string and assign it to the given
    /// row and column applying the same styling to each cell
    pub fn setFormatted(self: *@This(), col: u16, row: u16, style: ?Style, comptime fmt: []const u8, args: anytype) !void {
        const pos: usize = @intCast((row * self.area.width) + col);
        if (pos >= self.inner.len) return error.OutOfBounds;

        var context = WriterContext {
            .buffer = self,
            .area = Rect { .x = col, .y = row, .width = self.area.width, .height = self.area.height },
            .style = style,
        };
        const writer = Writer { .context = &context };

        try writer.print(fmt, args);
    }

    /// Assign a string slice to the given row and column applying the same
    /// styling to each cell
    pub fn setSlice(self: *@This(), col: u16, row: u16, slice: []const u8, style: ?Style) void {
        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = slice };
        var i: usize = 0;
        while (iter.nextCodepoint()) |codepoint| : (i += 1) {
            self.set(col + @as(u16, @intCast(i)), row, codepoint, style);
        }
    }

    /// Repeat the same character and styling `n` times in the same row starting at the given column
    pub fn setRepeatX(self: *@This(), col: u16, row: u16, n: usize, char: anytype, style: ?Style) void {
        for (0..n) |i| {
            self.set(col + @as(u16, @intCast(i)), row, char, style);
        }
    }

    /// Repeat the same character and styling `n` times in the same column starting at the given row
    pub fn setRepeatY(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) void {
        for (0..count) |i| {
            self.set(x, y + @as(u16, @intCast(i)), char, style);
        }
    }

    /// Get a cell based on the row and column
    pub fn get(self: *const @This(), col: u16, row: u16) ?*const Cell {
        const pos: usize = @intCast((row * self.area.width) + col);
        if (col >= self.area.width or row >= self.area.height or pos >= self.inner.len) return null;

        return &self.inner[pos];
    }

    /// Render a component that implements the `render` method or function
    ///
    /// All of the method or function's arguments will be injected/resolved
    /// based on what is available to be provided.
    ///
    /// Available Arguments:
    ///     - @This() | *const @This() | *@This()
    ///     - Rect
    ///     - *Buffer | *const Buffer
    ///     - std.mem.Allocator
    pub fn render(self: *@This(), component: anytype, area: Rect) !void {
        try renderComponent(self.alloc, component, self, area);
    }

    /// Render a component that implements the `renderWithState` method or function
    ///
    /// This will pass the state on to the method or functions argument that matches the same type.
    ///
    /// All of the method or function's arguments will be injected/resolved
    /// based on what is available to be provided.
    ///
    /// Available Arguments:
    ///     - @This() | *const @This() | *@This()
    ///     - Rect
    ///     - *Buffer | *const Buffer
    ///     - std.mem.Allocator
    ///     - @TypeOf(state)
    pub fn renderWithState(self: *@This(), component: anytype, area: Rect, state: anytype) !void {
        try renderComponentWithState(self.alloc, component, self, area, state);
    }
};
