const std = @import("std");
const zerm = @import("zerm");

const Style = zerm.style.Style;
const Cursor = zerm.action.Cursor;
const Stream = zerm.Stream;
const getTermSize = zerm.action.getTermSize;

pub const buffer = @import("./buffer.zig");
pub const widget = @import("./widget.zig");
pub const symbols = @import("./symbols.zig");

pub const Buffer = buffer.Buffer;
pub const Cell = buffer.Cell;

/// Represents the terminal and it's current state
///
/// Handles rendering and diffing buffer cells between
/// renders.
pub const Terminal = struct {
    allo: std.mem.Allocator,
    source: std.fs.File,

    area: Rect,
    /// [2]Buffer { PREVIOUS, CURRENT }
    buffers: [2]Buffer,

    pub fn init(allo: std.mem.Allocator, source: Stream) !@This() {
        const cols, const rows = try getTermSize();
        const area = Rect{ .width = cols, .height = rows };
        return .{
            .buffers = .{
                try Buffer.init(allo, area),
                try Buffer.init(allo, area),
            },
            .area = area,
            .source = if (source == .stdout) std.io.getStdOut() else std.io.getStdErr(),
            .allo = allo,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (&self.buffers) |*b| b.deinit();
    }

    /// Resize the terminal
    ///
    /// This causes the cells to be reallocated according to the new
    /// terminal size
    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        self.area = Rect{ .width = w, .height = h };
        for (&self.buffers) |*b| try b.resize(w, h);
        self.buffers[0].fill(self.buffers[0].area, ' ', null);
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
    pub fn renderWithState(self: *@This(), component: anytype, state: anytype) !void {
        // Call render function on component(s)
        try renderComponentWithState(self.allo, &self.buffers[1], self.buffers[1].area, component, state, null);
        try self.write(self.source.writer());
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
    pub fn render(self: *@This(), component: anytype) !void {
        // Call render function on component(s)
        try renderComponent(self.allo, &self.buffers[1], self.buffers[1].area, component, null);
        try self.write(self.source.writer());
    }

    /// Write the buffer to a given writer optimizing with the changes
    /// from the previous render
    pub fn write(self: *const @This(), writer: anytype) !void {
        const buff = &self.buffers[1];
        const previous = &self.buffers[0];

        var buffered_writer = std.io.bufferedWriter(writer);
        var output = buffered_writer.writer();

        var jump = false;
        var style: ?Style = null;

        try output.print("{s}", .{ Cursor { .col = self.area.x, .row = self.area.y } });
        for (0..self.area.height) |h| {
            for (0..self.area.width) |w| {
                const pos: usize = @intCast((h * self.area.width) + w);
                if (pos >= buff.inner.len) break;

                const cell = &buff.inner[pos];
                const old_cell = &previous.inner[pos];

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
                    previous.inner[pos] = cell.*;
                } else {
                    jump = true;
                }

                buff.inner[pos] = .{};
            }

            if (h < self.area.height-1 and !jump) {
                try output.print("\r\n", .{});
            }
        }

        if (style) |s| try output.print("{s}", .{ s.reset() });

        try buffered_writer.flush();
    }
};

/// Render a component that implements the `renderWithState` method or function to the buffer
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
pub fn renderComponentWithState(allocator: std.mem.Allocator, buff: *Buffer, rect: Rect, component: anytype, state: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => {
            const name: []const u8 = if (@hasDecl(T, "renderWithState"))
                "renderWithState"
            else if (@hasDecl(T, "render"))
                 "render"
            else return;
            const func = @field(T, name);

            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            errdefer arena.deinit();

            const params = @typeInfo(@TypeOf(func)).@"fn".params;
            var args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
            inline for (params, 0..) |param, i| {
                args[i] = switch(param.type.?) {
                    *const T, *T => component,
                    T => component.*,
                    *Buffer, *const Buffer => buff,
                    Rect => rect,
                    @TypeOf(state) => state,
                    std.mem.Allocator => arena.allocator(),
                    else => @compileError("unsupported renderWithState function argument type " ++ @typeName(param.type.?)),
                };
            }
            try @call(.auto, func, args);
        },
        .pointer => |p| {
            switch (@typeInfo(p.child)) {
                .@"struct" => {
                    const name: []const u8 = if (@hasDecl(p.child, "renderWithState"))
                        "renderWithState"
                    else if (@hasDecl(p.child, "render"))
                         "render"
                    else return;

                    var arena = std.heap.ArenaAllocator.init(allocator);
                    defer arena.deinit();
                    errdefer arena.deinit();

                    const func = @field(p.child, name);
                    const params = @typeInfo(@TypeOf(func)).@"fn".params;
                    var args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;

                    inline for (params, 0..) |param, i| {
                        args[i] = switch(param.type.?) {
                            *const p.child, *p.child => component,
                            p.child => component.*,
                            *Buffer, *const Buffer => buff,
                            Rect => rect,
                            @TypeOf(state) => state,
                            std.mem.Allocator => arena.allocator(),
                            else => @compileError("unsupported renderWithState function argument type " ++ @typeName(param.type.?)),
                        };
                    }
                    try @call(.auto, func, args);
                },
                else => {
                    switch (p.child) {
                        []const u8 => try buff.setSlice(rect.x, rect.y, component, style),
                        u21, u8, u32, comptime_int => try buff.set(rect.x, rect.y, component, style),
                        else => try buff.setFormatted(rect.x, rect.y, style, "{s}", .{ component }),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buff.setSlice(rect.x, rect.y, component, style),
                u21, u8, u32, comptime_int => try buff.set(rect.x, rect.y, component, style),
                else => try buff.setFormatted(rect.x, rect.y, style, "{s}", .{ component }),
            }
        }
    }
}

/// Render a component that implements the `render` method or function to the buffer
///
/// All of the method or function's arguments will be injected/resolved
/// based on what is available to be provided.
///
/// Available Arguments:
///     - @This() | *const @This() | *@This()
///     - Rect
///     - *Buffer | *const Buffer
///     - std.mem.Allocator
pub fn renderComponent(allocator: std.mem.Allocator, buff: *Buffer, rect: Rect, component: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => if (@hasDecl(T, "render")) {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            errdefer arena.deinit();

            const params = @typeInfo(@TypeOf(T.render)).@"fn".params;
            var args: std.meta.ArgsTuple(@TypeOf(T.render)) = undefined;
            inline for (params, 0..) |param, i| {
                args[i] = switch(param.type.?) {
                    *const T, *T => &component,
                    T => component,
                    *Buffer, *const Buffer => buff,
                    Rect => rect,
                    std.mem.Allocator => arena.allocator(),
                    else => @compileError("unsupported renderWithState function argument type " ++ @typeName(param.type.?)),
                };
            }
            try @call(.auto, T.render, args);
        },
        .pointer => |p| {
            switch (@typeInfo(p.child)) {
                .@"struct" => if (@hasDecl(p.child, "render")) {
                    var arena = std.heap.ArenaAllocator.init(allocator);
                    defer arena.deinit();
                    errdefer arena.deinit();

                    const params = @typeInfo(@TypeOf(p.child.render)).@"fn".params;
                    var args: std.meta.ArgsTuple(@TypeOf(p.child.render)) = undefined;
                    inline for (params, 0..) |param, i| {
                        args[i] = switch(param.type.?) {
                            *const p.child, *p.child => component,
                            p.child => component.*,
                            *Buffer, *const Buffer => buff,
                            Rect => rect,
                            std.mem.Allocator => arena.allocator(),
                            else => @compileError("unsupported renderWithState function argument type " ++ @typeName(param.type.?)),
                        };
                    }
                    try @call(.auto, p.child.render, args);
                },
                else => {
                    switch (p.child) {
                        []const u8 => try buff.setSlice(rect.x, rect.y, component, style),
                        u21, u8, u32, comptime_int => try buff.set(rect.x, rect.y, component, style),
                        else => try buff.setFormatted(rect.x, rect.y, style, "{s}", .{ component }),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buff.setSlice(rect.x, rect.y, component, style),
                u21, u8, u32, comptime_int => try buff.set(rect.x, rect.y, component, style),
                else => try buff.setFormatted(rect.x, rect.y, style, "{s}", .{ component }),
            }
        }
    }
}

/// Represents a component that will be renderd with a given style
pub fn Styled(T: type) type {
    return struct{
        value: T,
        style: Style,

        pub fn init(value: T, style: Style) @This() {
            return .{ .value = value, .style = style };
        }

        pub fn render(self: *@This(), buff: *Buffer, rect: Rect) !void {
            renderComponent(buff, rect, self.value, self.style);
        }
    };
}

/// Represents a specific area in a buffer
///
/// `x` and `y` represent the starting location
pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    /// Create a new `Rect` that has the padding applied
    pub fn padded(self: *const @This(), padding: Padding) Rect {
        return .{
            .x = self.x + padding.left,
            .y = self.y + padding.top,
            .width = self.width - padding.left - padding.right,
            .height = self.height - padding.top - padding.bottom,
        };
    }
};

/// Spacing on the inside of an area starting from it's edges
///
/// # Example
///
/// ```zig
/// Padding.symmetric(3, 1)
/// ```
/// ```
/// ┌─────────────┐
/// │             │ Padding:
/// │   ███████   │    left: 3
/// │   ███████   │    right: 3
/// │   ███████   │    top: 1
/// │   ███████   │    bottom: 1
/// │             │
/// └─────────────┘
/// ```
///
/// ```zig
/// Padding.proportional(1)
/// ```
/// ```
/// ┌─────────────┐
/// │             │ Padding:
/// │  █████████  │    left: 2
/// │  █████████  │    right: 2
/// │  █████████  │    top: 1
/// │  █████████  │    bottom: 1
/// │             │
/// └─────────────┘
/// ```
pub const Padding = struct {
    left: u16 = 0,
    right: u16 = 0,
    top: u16 = 0,
    bottom: u16 = 0,

    /// Apply the same padding to all sides
    pub fn uniform(size: u16) @This() {
        return .{ .left = size, .right = size, .bottom = size, .top = size };
    }

    /// Apply the same padding to both the `left` and the `right`
    pub fn horizontal(size: u16) @This() {
        return .{ .left = size, .right = size };
    }

    /// Apply the same padding to both the `top` and the `bottom`
    pub fn vertical(size: u16) @This() {
        return .{ .bottom = size, .top = size };
    }

    /// Apply the `x` padding to the `left` and `right` and the `y` padding
    /// to the `top` and `bottom`
    pub fn symmetric(x: u16, y: u16) @This() {
        return .{ .left = x, .right = x, .bottom = y, .top = y };
    }

    /// Same as `uniform` but makes the values visually proportional
    ///
    /// This means that there is a `2x` multiplier applied horizontally and `1x`
    /// multiplier vertically.
    pub fn proportional(size: u16) @This() {
        return .{ .left = size * 2, .right = size * 2, .bottom = size, .top = size };
    }
};
