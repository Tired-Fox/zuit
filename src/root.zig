const std = @import("std");

const Style = @import("termz").style.Style;
const Cursor = @import("termz").action.Cursor;
const Source = @import("termz").Source;
const getTermSize = @import("termz").action.getTermSize;

pub const buffer = @import("./buffer.zig");
pub const widget = @import("./widget.zig");

pub const Buffer = buffer.Buffer;
pub const Cell = buffer.Cell;

pub const Terminal = struct {
    allo: std.mem.Allocator,
    source: std.fs.File,

    buffer: Buffer,
    previous: []Cell,

    pub fn init(allo: std.mem.Allocator, source: Source) !@This() {
        const cols, const rows = try getTermSize();
        return .{
            .buffer = try Buffer.init(allo, Rect{ .width = cols, .height = rows }),
            .previous = try allo.alloc(Cell, @intCast(cols * rows)),
            .source = if (source == .Stdout) std.io.getStdOut() else std.io.getStdErr(),
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
        try renderComponentWithState(&self.buffer, self.buffer.area, component, state, null);

        // Render buffer iterating previous at the same time
        try self.buffer.render(self.source.writer(), self.previous);
    }

    pub fn render(self: *@This(), component: anytype) !void {
        // Call render function on component(s)
        const region = Rect { .x = 0, .y = 0, .width = self.buffer.area.width, .height = self.buffer.area.height };
        try renderComponent(&self.buffer, region, component, null);

        // Render buffer iterating previous at the same time
        try self.buffer.render(self.source.writer(), self.previous);
    }
};

fn renderComponentWithState(buff: *Buffer, rect: Rect, component: anytype, state: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .Struct => {
            const name: []const u8 = if (@hasDecl(T, "renderWithState"))
                "renderWithState"
            else if (@hasDecl(T, "render"))
                 "render"
            else return;
            const func = @field(T, name);

            const params = @typeInfo(@TypeOf(func)).Fn.params;
            var args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
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
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Struct => {
                    const name: []const u8 = if (@hasDecl(p.child, "renderWithState"))
                        "renderWithState"
                    else if (@hasDecl(p.child, "render"))
                         "render"
                    else return;

                    const func = @field(p.child, name);
                    const params = @typeInfo(@TypeOf(func)).Fn.params;
                    var args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
                    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                    defer arena.deinit();
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
                        []const u8 => try buff.setSlice(0, 0, component, style),
                        u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                        else => @compileError(@typeName(T) ++ " does not support rendering"),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buff.setSlice(0, 0, component, style),
                u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                else => @compileError(@typeName(T) ++ " does not support rendering"),
            }
        }
    }
}

fn renderComponent(buff: *Buffer, rect: Rect, component: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .Struct => if (@hasDecl(T, "render")) {
            const params = @typeInfo(@TypeOf(T.render)).Fn.params;
            var args: std.meta.ArgsTuple(@TypeOf(T.render)) = undefined;
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
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
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Struct => if (@hasDecl(p.child, "render")) {
                    const params = @typeInfo(@TypeOf(p.child.render)).Fn.params;
                    var args: std.meta.ArgsTuple(@TypeOf(p.child.render)) = undefined;
                    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                    defer arena.deinit();
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
                        []const u8 => try buff.setSlice(0, 0, component, style),
                        u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                        else => @compileError(@typeName(T) ++ " does not support rendering"),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buff.setSlice(0, 0, component, style),
                u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                else => @compileError(@typeName(T) ++ " does not support rendering"),
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
};
