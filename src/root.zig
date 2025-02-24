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
        if (self.previous) |prev| self.allo.free(prev);
        self.previous = try self.allo.dupe(Cell, self.buffer.inner);
    }

    pub fn render(self: *@This(), component: anytype) !void {
        // Call render function on component(s)
        const area = Rect { .width = self.buffer.width, .height = self.buffer.height };
        try render_component(&self.buffer, area, component, null);

        // Render buffer iterating previous at the same time
        try self.buffer.render(self.source.writer(), self.previous);

        // Snapshot the buffer cells and store them in the previous frame buffer
        if (self.previous) |prev| self.allo.free(prev);
        self.previous = try self.allo.dupe(Cell, self.buffer.inner);
    }
};

fn render_component_with_state(buff: *Buffer, rect: Rect, component: anytype, state: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .Struct => {
            switch (std.meta.fields(T)) {
                .Struct, .Enum => if (@hasDecl(T, "render_with_state")) {
                    try component.render_with_state(buff, rect, state);
                } else if (@hasDecl(T, "render")) {
                    try component.render(buff, rect);
                },
                .Union => |fields| inline for (fields) |field| {
                    try render_component_with_state(buff, @field(component, field.name), state, style);
                }
            }
        },
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Struct => if (@hasDecl(p.child, "render_with_state")) {
                    try component.render_with_state(buff, rect, state);
                } else if (@hasDecl(T, "render")) {
                    try component.render(buff, rect);
                },
                else => {
                    switch (p.child) {
                        []const u8 => try buff.setSlice(0, 0, component, style),
                        u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                        else => try buff.setFormatable(0, 0, component, style),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buff.setSlice(0, 0, component, style),
                u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                else => try buff.setFormatable(0, 0, component, style),
            }
        }
    }
}

fn render_component(buff: *Buffer, rect: Rect, component: anytype, style: ?Style) !void {
    const T = @TypeOf(component);
    const info = @typeInfo(T);

    switch (info) {
        .Struct => {
            switch (std.meta.fields(T)) {
                .Struct, .Enum => if (@hasDecl(T, "render")) {
                    try component.render(buff, rect);
                },
                .Union => |fields| inline for (fields) |field| {
                    try render_component(buff, @field(component, field.name), style);
                }
            }
        },
        .Pointer => |p| {
            switch (@typeInfo(p.child)) {
                .Struct => {
                    if (@hasDecl(p.child, "render")) {
                        try component.render(buff, rect);
                    }
                },
                else => {
                    switch (p.child) {
                        []const u8 => try buff.setSlice(0, 0, component, style),
                        u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                        else => try buff.setFormatable(0, 0, component, style),
                    }
                }
            }
        },
        else => {
            switch (T) {
                []const u8 => try buff.setSlice(0, 0, component, style),
                u21, u8, u32, comptime_int => try buff.set(0, 0, component, style),
                else => try buff.setFormatable(0, 0, component, style),
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
            render_component(buff, rect, self.value, self.style);
        }
    };
}

pub const Rect = struct {
    x: u16 = 0,
    y: u16 = 0,
    width: u16 = 0,
    height: u16 = 0,
};
