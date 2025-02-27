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
    });
}

fn cleanup() !void {
    try Screen.disableRawMode();
    try execute(.Stdout, .{
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

    var app = App{};

    while (true) {
        if (try stream.parseEvent()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.matches(.{ .code = KeyCode.Esc })) break;
                    if (key.matches(.{ .code = KeyCode.char('c'), .ctrl = true })) break;
                    if (key.matches(.{ .code = KeyCode.char('C'), .ctrl = true })) break;
                    if (key.matches(.{ .code = KeyCode.char('q') })) break;
                },
                .resize => |resize| {
                    try term.resize(resize[0], resize[1]);
                },
                else => {}
            }
        }

        try term.render(&app);
    }
}

const App = struct {
    pub fn render(area: zuit.Rect, buffer: *zuit.Buffer, allo: std.mem.Allocator) !void {
        const block = widget.Block {
            .borders = widget.Borders.all(),
            .titles = &.{
                .{
                    .text = " Zuit Layout ",
                    .style = .{ .fg = Color.Blue, .bold = true },
                    .position = .TopCenter
                },
            },
        };
        try block.render(buffer, area);
        try widget.Clear.render(buffer, block.inner(area));

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

        const message = widget.Paragraph {
            .lines = &.{
                widget.Line.center(&.{ widget.Span.init("Hello, Zuit!") }),
                widget.Line.center(&.{}),
                widget.Line.center(&.{ widget.Span.init("Repository: https://github.com/Tired-Fox/zuit") }),
                widget.Line.center(&.{ widget.Span.init("Terminal API: https://github.com/Tired-Fox/termz") }),
                widget.Line.center(&.{ widget.Span.init("Press `Esc`, `Ctrl-C` or `q` to stop running.") }),
            }
        };
        try message.render(buffer, vert[0]);

        const hoz = widget.Layout(5).horizontal(&constraints).split(vert[1]);
        for (hoz) |a| {
            const container = widget.Block.bordered();
            try container.render(buffer, a);
            const inner = container.inner(a);

            const text = try std.fmt.allocPrint(allo, "{d}", .{ a.width });
            defer allo.free(text);

            try widget.Line.center(&.{ widget.Span.init(text) }).render(buffer, inner);
            // try buffer.setFormatted(inner.x, inner.y, null, "{d}", .{ a.width });
        }
    }
};
