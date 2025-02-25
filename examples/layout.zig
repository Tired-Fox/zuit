const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;

const Cursor = termz.action.Cursor;
const Screen = termz.action.Screen;
const Capture = termz.action.Capture;
const getTermSize = termz.action.getTermSize;

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
    const cols, const rows = try getTermSize();
    std.debug.print("{d} x {d}", .{ cols, rows });

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

    var app = App{};

    while (true) {
        if (try stream.parseEvent()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.matches(.{ .code = KeyCode.char('q') })) break;
                    if (key.matches(.{ .code = KeyCode.char('c'), .ctrl = true })) break;
                    if (key.matches(.{ .code = KeyCode.char('C'), .ctrl = true })) break;

                    switch (key.code) {
                        .char => |last| app.last_char = last,
                        else => {},
                    }
                },
                else => {}
            }
        }

        try term.render(&app);
    }
}

const App = struct {
    last_char: ?u21 = null,

    pub fn render(self: *const @This(), area: zuit.Rect, buffer: *zuit.Buffer, allo: std.mem.Allocator) !void {
        var top_center: []u8 = "";
        if (self.last_char) |last| {
            var buff: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(last, &buff);
            top_center = try std.fmt.allocPrint(allo, "Key: {s}", .{ buff[0..@intCast(len)] });
        }

        const block = widget.Block {
            .borders = widget.Borders.all(),
            .titles = .{
                .top_left = "TopLeft",
                .top_center = top_center,
                .top_right = "TopRight",
                .bottom_left = "BottomLeft",
                .bottom_center = "BottomCenter",
                .bottom_right = "BottomRight",
            },
        };
        try block.render(buffer, area);

        const vert = widget.Layout(3).vertical(.{
            widget.Constraint.fill(1),
            widget.Constraint.length(3),
            widget.Constraint.fill(1),
        }).split(block.inner(area));

        const constraints = [_]widget.Constraint{
            widget.Constraint.min(10),
            widget.Constraint.max(5),
            widget.Constraint.max(5),
            widget.Constraint.fill(2),
            widget.Constraint.fill(1),
        };

        const hoz = widget.Layout(5).horizontal(&constraints).split(vert[1]);
        for (hoz) |a| {
            const container = widget.Block {
                .borders = widget.Borders.all(),
            };
            try container.render(buffer, a);
            const inner = container.inner(a);

            try buffer.setFormatted(inner.x, inner.y, null, "{d}", .{ a.width });
        }
    }
};
