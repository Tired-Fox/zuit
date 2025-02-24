const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const Terminal = zuit.Terminal;
const Buffer = zuit.Buffer;
const Rect = zuit.Rect;

const Cursor = termz.action.Cursor;
const Screen = termz.action.Screen;
const Capture = termz.action.Capture;

const EventStream = termz.event.EventStream;
const KeyCode = termz.event.KeyCode;

const Color = termz.style.Color;
const Style = termz.style.Style;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;
const execute = termz.execute;

fn setup() !void {
    try Screen.enableRawMode();
    try execute(.Stdout, .{
        Screen.EnterAlternateBuffer,
        Cursor { .col = 1, .row = 1 },
        Cursor.Hide,
        Capture.EnableMouse,
        Capture.EnableFocus,
        Capture.EnableBracketedPaste,
    });
}

fn cleanup() !void {
    try Screen.disableRawMode();
    try execute(.Stdout, .{
        Capture.DisableMouse,
        Capture.DisableFocus,
        Capture.DisableBracketedPaste,
        Cursor.Show,
        Screen.LeaveAlternateBuffer,
    });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allo = arena.allocator();

    var term = try Terminal.init(allo, .Stdout);
    defer term.deinit();

    var stream = EventStream.init(allo);
    defer stream.deinit();

    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    try setup();
    errdefer _ = Screen.disableRawMode() catch { std.log.err("error disabling raw mode", .{}); };
    defer cleanup() catch { std.log.err("error cleaning up terminal", .{}); };

    var app = App { };
    defer if (app.message) |message| allo.free(message);

    var stamp = try std.time.Instant.now();
    var i: usize = 0;
    while (true) {
        if (i > 10) break;

        if (try stream.parseEvent()) |event| {
            switch (event) {
                .key => |evt| {
                    if (evt.matches(.{ .code = KeyCode.char('q') })) break;
                    if (evt.matches(.{ .code = KeyCode.char('c'), .ctrl = true })) break;
                    if (evt.matches(.{ .code = KeyCode.char('C'), .ctrl = true })) break;
                },
                else => {}
            }
        }

        const elapsed = try std.time.Instant.now();
        if (elapsed.since(stamp) / std.time.ns_per_s >= 1) {
            i += 1;
            if (app.message) |message| allo.free(message);
            app.message = try std.fmt.allocPrint(allo, "Iteration #{d}", .{ i });
            stamp = try std.time.Instant.now();
        }

        try term.render_with_state(&app, &i);
    }
}

const App = struct {
    message: ?[]const u8 = null,

    pub fn render_with_state(self: *@This(), buffer: *Buffer, rect: Rect, state: *usize) !void {
        var block = Block.bordered()
            .border_set(if (state.* % 2 == 0) Border.ROUNDED else Border.DOUBLE);

        try block.render(buffer, rect);
        const inner = block.inner(rect);

        if (self.message) |message| {
            try buffer.setSlice(
                @divFloor(inner.width, 2) - @as(u16, @intCast(@divFloor(message.len, 2))),
                @divFloor(inner.height, 2),
                message,
                Style { .fg = switch (state.* % 6) {
                    0 => Color.Red,
                    1 => Color.Green,
                    2 => Color.Yellow,
                    3 => Color.Blue,
                    4 => Color.Magenta,
                    else => Color.Cyan,
                }},
            );
        }
    }
};

pub const Border = struct {
    top_left: u21,
    top_right: u21,
    bottom_left: u21,
    bottom_right: u21,
    left: u21,
    right: u21,
    top: u21,
    bottom: u21,

    pub const ROUNDED: @This() = .{
        .top_left = '╭',
        .top_right = '╮',
        .bottom_left = '╰',
        .bottom_right = '╯',
        .left = '│',
        .right = '│',
        .top = '─',
        .bottom = '─',
    };

    pub const SINGLE: @This() = .{
        .top_left = '┌',
        .top_right = '┐',
        .bottom_left = '└',
        .bottom_right = '┘',
        .left = '│',
        .right = '│',
        .top = '─',
        .bottom = '─',
    };

    pub const DOUBLE: @This() = .{
        .top_left = '╔',
        .top_right = '╗',
        .bottom_left = '╚',
        .bottom_right = '╝',
        .left = '║',
        .right = '║',
        .top = '═',
        .bottom = '═',
    };
};

const Block = struct {
    border_style: Border = Border.SINGLE,
    border: bool = false,

    pub fn init() @This() {
        return .{};
    }

    pub fn bordered() @This() {
        return .{ .border = true };
    }

    pub fn border_set(self: @This(), style: Border) @This() {
        return .{
            .border = self.border,
            .border_style = style
        };
    }

    pub fn inner(self: *const @This(), rect: Rect) Rect {
        if (self.border) {
            return Rect {
                .x = rect.x + 1,
                .y = rect.y + 1,
                .width = rect.width - 2,
                .height = rect.height - 2
            };
        }
        return rect;
    }

    pub fn render(self: *@This(), buffer: *Buffer, rect: Rect) !void {
        try buffer.set(0, 0, self.border_style.top_left, null);
        try buffer.setRepeatX(1, 0, rect.width-2, self.border_style.top, null);
        try buffer.set(rect.width-1, 0, self.border_style.top_right, null);

        for (1..rect.height-1) |i| {
            try buffer.set(0, @intCast(i), self.border_style.left, null);
            try buffer.set(rect.width-1, @intCast(i), self.border_style.right, null);
        }

        try buffer.set(0, rect.height-1, self.border_style.bottom_left, null);
        try buffer.setRepeatX(1, rect.height-1, rect.width-2, self.border_style.bottom, null);
        try buffer.set(rect.width-1, rect.height-1, self.border_style.bottom_right, null);
    }
};
