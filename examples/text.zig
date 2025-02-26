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
    pub fn render(area: zuit.Rect, buffer: *zuit.Buffer) !void {
        try widget.Clear.render(buffer, area);

        const v = widget.Layout(3)
            .vertical(.{
                widget.Constraint.length(3),
                widget.Constraint.length(3),
                widget.Constraint.fill(1),
            })
            .split(area);

        const a = widget.Block.bordered();
        try a.render(buffer, v[0]);
        try widget.Span.styled("Hello, world", .{ .fg = Color.Red })
            .render(buffer, a.inner(v[0]));

        const b = widget.Block.bordered();
        try b.render(buffer, v[1]);

        try widget.Line.center(&.{
            widget.Span.styled("┓┓┓┓┓ ", .{ .fg = Color.Magenta }),
            widget.Span.styled("┓┓┓┓┓┓", .{ .fg = Color.Red }),
        }).render(buffer, b.inner(v[1]));

        const c = widget.Block.bordered();
        try c.render(buffer, v[2]);

        try widget.Paragraph.init(&.{
            widget.Line.init(&.{
                widget.Span.styled("Hello, ", .{ .fg = Color.Red }),
                widget.Span.styled("world", .{ .fg = Color.Magenta }),
            })
        }).render(buffer, b.inner(v[1]));
    }
};
