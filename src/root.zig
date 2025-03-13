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

pub const Terminal = struct {
    allo: std.mem.Allocator,
    source: std.fs.File,

    buffer: Buffer,
    previous: []Cell,

    pub fn init(allo: std.mem.Allocator, source: Stream) !@This() {
        const cols, const rows = try getTermSize();
        return .{
            .buffer = try Buffer.init(allo, Rect{ .width = cols, .height = rows }),
            .previous = try allo.alloc(Cell, @intCast(cols * rows)),
            .source = if (source == .stdout) std.io.getStdOut() else std.io.getStdErr(),
            .allo = allo,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allo.free(self.previous);
        self.buffer.deinit();
    }

    pub fn resize(self: *@This(), w: u16, h: u16) !void {
        self.allo.free(self.previous);
        self.previous = try self.allo.alloc(Cell, @intCast(w * h));
        for (self.previous) |*cell| cell.* = .{};
        try self.buffer.resize(w, h);
    }

    pub fn renderWithState(self: *@This(), component: anytype, state: anytype) !void {
        // Call render function on component(s)
        try renderComponentWithState(self.allo, &self.buffer, self.buffer.area, component, state, null);

        // Render buffer iterating previous at the same time
        try self.buffer.write(self.source.writer(), self.previous);
    }

    pub fn render(self: *@This(), component: anytype) !void {
        // Call render function on component(s)
        const region = Rect { .x = 0, .y = 0, .width = self.buffer.area.width, .height = self.buffer.area.height };
        try renderComponent(self.allo, &self.buffer, region, component, null);

        // Render buffer iterating previous at the same time
        try self.buffer.write(self.source.writer(), self.previous);
    }
};

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

pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,

    pub fn padded(self: *const @This(), padding: widget.Padding) Rect {
        return .{
            .x = self.x + padding.left,
            .y = self.y + padding.top,
            .width = self.width - padding.left - padding.right,
            .height = self.height - padding.top - padding.bottom,
        };
    }

    pub fn inner(self: *const @This(), margin: Margin) @This() {
        return .{
            .x = self.x + margin.horizontal,
            .y = self.y + margin.vertical,
            .width = self.width - (margin.horizontal * 2),
            .height = self.height - (margin.vertical * 2),
        };
    }

    pub const Margin = struct {
        vertical: u16 = 0,
        horizontal: u16 = 0,
    };
};
