const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;

const Cursor = termz.action.Cursor;
const Screen = termz.action.Screen;
const Capture = termz.action.Capture;
const getTermSize = termz.action.getTermSize;

const EventStream = termz.event.EventStream;

const Style = termz.style.Style;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;
const execute = termz.execute;

fn setup() !void {
    try Screen.enableRawMode();
    try execute(.stdout, .{
        Screen.EnterAlternateBuffer,
        Cursor { .col = 1, .row = 1 },
        Cursor.Hide,
    });
}

fn cleanup() !void {
    try Screen.disableRawMode();
    try execute(.stdout, .{
        Cursor.Show,
        Screen.LeaveAlternateBuffer,
    });
}

pub fn main() !void {
    // Use debug allocator to help catch memory leaks
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allo = gpa.allocator();

    var term = try zuit.Terminal.init(allo, .stdout);
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
                    if (key.matches(.{ .code = .char('q') })) break;
                    if (key.matches(.{ .code = .char('c'), .ctrl = true })) break;
                    if (key.matches(.{ .code = .char('C'), .ctrl = true })) break;
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
            .vertical(&.{
                .{ .length = 3 },
                .{ .length = 3 },
                .{ .fill = 1 },
            })
            .split(area);

        const a = widget.Block.bordered();
        try a.render(buffer, v[0]);
        try widget.Span.styled("Hello, world", .{ .fg = .red })
            .render(buffer, a.inner(v[0]));

        const b = widget.Block.bordered();
        try b.render(buffer, v[1]);

        try widget.Line.center(&.{
            .styled("┓┓┓┓┓ ", .{ .fg = .magenta }),
            .styled("┓┓┓┓┓┓", .{ .fg = .red }),
        }).render(buffer, b.inner(v[1]));

        const c = widget.Block.bordered();
        try c.render(buffer, v[2]);
        var special = c.inner(v[2]);
        special.width = 8;

        try (widget.Paragraph {
            .lines = &.{
                widget.Line.init(&[_]widget.Span{
                    widget.Span.styled("  Hello, ", .{ .fg = .red }),
                    widget.Span.styled("world  ", .{ .fg = .magenta }),
                }),
                .init(&.{ .init("  How are you?  ") }),
                .init(&.{ .init("  Today?  ") })
            },
            .text_align = .center,
            .trim = true,
            .wrap = true,
        }).render(buffer, special);
    }
};
