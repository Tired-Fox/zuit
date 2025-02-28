const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;

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
    // Use debug allocator to help catch memory leaks
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allo = gpa.allocator();

    var term = try zuit.Terminal.init(allo, .Stdout);
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
        if (i > 11) break;

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

        try term.renderWithState(&app, &i);
        if (i % 5 == 0) try term.render(widget.Clear);
    }
}

const App = struct {
    message: ?[]const u8 = null,

    pub fn renderWithState(self: *@This(), buffer: *zuit.Buffer, rect: zuit.Rect, state: *usize) !void {
        const color = switch (state.* % 6) {
            0 => Color.Red,
            1 => Color.Green,
            2 => Color.Yellow,
            3 => Color.Blue,
            4 => Color.Magenta,
            else => Color.Cyan,
        };

        var block = widget.Block {
            .borders = widget.Borders.all(),
            .set = @as(widget.BorderType, @enumFromInt(state.* % widget.BorderType.count())).set(),
            .padding = widget.Padding.proportional(8),
            .border_style = .{ .fg = color, .bg = Color.black },
            .style = .{ .bg = Color.black },
        };

        try block.render(buffer, rect);
        const inner = block.inner(rect);

        try (widget.Block {
            .borders = widget.Borders.all(),
            .border_style = .{ .bg = Color.Default },
            .style = .{ .bg = Color.Default },
        }).render(buffer, inner);

        if (self.message) |message| {
            // try buffer.setFormatted(x: u16, y: u16, item: anytype, style: ?Style)
            buffer.setSlice(
                inner.x + @divFloor(inner.width, 2) - @as(u16, @intCast(@divFloor(message.len, 2))),
                inner.y + @divFloor(inner.height, 2),
                message,
                .{ .fg = color },
            );
        }
    }
};
