const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;

const Cursor = termz.action.Cursor;
const Screen = termz.action.Screen;
const Capture = termz.action.Capture;
const getTermSize = termz.action.getTermSize;

const EventStream = termz.event.EventStream;

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
                    if (key.matches(.{ .code = .esc })) break;
                    if (key.matches(.{ .code = .char('c'), .ctrl = true })) break;
                    if (key.matches(.{ .code = .char('C'), .ctrl = true })) break;
                    if (key.matches(.{ .code = .char('q') })) break;
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
            .borders = .all,
            .titles = &.{
                .{
                    .text = " Zuit Layout ",
                    .style = .{ .fg = .blue, .mod = .{ .bold = true } },
                    .position = .top_center
                },
            },
        };
        try block.render(buffer, area);
        try widget.Clear.render(buffer, block.inner(area));

        const vert = widget.Layout(3).vertical(&.{
            .{ .fill = 1 },
            .{ .length = 3 },
            .{ .fill = 1 },
        }).split(block.inner(area));

        const constraints = [_]widget.Constraint{
            .{ .min = 10 },
            .{ .max = 5 },
            .{ .max = 5 },
            .{ .fill = 2 },
            .{ .fill = 1 },
        };

        const message = widget.Paragraph {
            .lines = &.{
                .empty,
                .center(&.{ .init("Hello, Zuit!") }),
                .empty,
                .center(&.{
                    .init("Repository: "),
                    .styled("https://github.com/Tired-Fox/zuit", .{ .fg = .green, .mod = .{ .underline = .single } })
                }),
                .center(&.{
                    .init("Terminal API: "),
                    .styled("https://github.com/Tired-Fox/termz", .{ .fg = .green, .mod = .{ .underline = .single } })
                }),
                .empty,
                .center(&.{ .styled("Press `Esc`, `Ctrl-C` or `q` to stop running.", .italic) }),
                .empty,
            }
        };
        try message.render(buffer, vert[0]);

        const hoz = widget.Layout(5).horizontalWithSpacing(3, &constraints).split(vert[1]);
        for (hoz) |a| {
            const container = widget.Block.bordered();
            try container.render(buffer, a);
            const inner = container.inner(a);

            const text = try std.fmt.allocPrint(allo, "{d}", .{ a.width });
            defer allo.free(text);

            try widget.Line.center(&.{ .styled(text, .{ .fg = .magenta, .mod = .{ .bold = true } }) }).render(buffer, inner);
            // try buffer.setFormatted(inner.x, inner.y, null, "{d}", .{ a.width });
        }
    }
};
