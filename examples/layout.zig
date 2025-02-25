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

    const app = App {};

    try term.render(&app);

    while (true) {
        if (try stream.parseEvent()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.matches(.{ .code = KeyCode.char('q') })) break;
                    if (key.matches(.{ .code = KeyCode.char('c'), .ctrl = true })) break;
                    if (key.matches(.{ .code = KeyCode.char('C'), .ctrl = true })) break;
                },
                else => {}
            }
        }
    }
}

const App = struct {
    pub fn render(self: *const @This(), buffer: *zuit.Buffer, area: zuit.Rect) !void {
        _ = self;

        const vert = widget.Layout(2).vertical(.{
            widget.Constraint.length(1),
            widget.Constraint.length(3),
        }).split(area);

        const cols, const rows = try getTermSize();
        try buffer.setFormatted(vert[0].x, vert[0].y, null, "{d} x {d} {any}", .{ cols, rows, vert[1] });

        const constraints = [_]widget.Constraint{
            widget.Constraint.min(10),
            widget.Constraint.max(5),
            widget.Constraint.max(5),
            widget.Constraint.fill(2),
            widget.Constraint.fill(1),
        };

        const hoz = widget.Layout(5).horizontal(&constraints).split(vert[1]);
        for (0..hoz.len) |i| {
            try buffer.setFormatted(area.x, area.y + 4 + @as(u16, @intCast(i)), null, "{any}", .{ hoz[i] });
        }

        for (hoz) |a| {
            const block = widget.Block {
                .borders = widget.Borders.all(),
            };
            try block.render(buffer, a);
            const inner = block.inner(a);

            try buffer.setFormatted(inner.x, inner.y, null, "{d}", .{ a.width });
        }
    }
};
