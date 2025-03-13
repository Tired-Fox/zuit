const std = @import("std");
const zerm = @import("zerm");
const zuit = @import("zuit");

const widget = zuit.widget;

const Cursor = zerm.action.Cursor;
const Screen = zerm.action.Screen;
const Capture = zerm.action.Capture;
const getTermSize = zerm.action.getTermSize;

const EventStream = zerm.event.EventStream;

const Utf8ConsoleOutput = zerm.Utf8ConsoleOutput;
const execute = zerm.execute;

fn setup() !void {
    try Screen.enableRawMode();
    try execute(.stdout, .{
        Screen.enter_alternate_buffer,
        Cursor { .col = 1, .row = 1 },
        Cursor { .visibility = .hidden },
    });
}

fn cleanup() !void {
    try Screen.disableRawMode();
    try execute(.stdout, .{
        Cursor { .visibility = .visible },
        Screen.leave_alternate_buffer,
    });
}

pub fn main() !void {
    // Use debug allocator to help catch memory leaks
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() == .leak) { std.debug.print("memory leak detected", .{}); };
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
    try term.render(&app);

    while (true) {
        if (try stream.parseEvent()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.matches(&.{ 
                        .{ .code = .esc },
                        .{ .code = .char('c'), .ctrl = true },
                        .{ .code = .char('C'), .ctrl = true },
                        .{ .code = .char('q') }
                    })) break;
                },
                .resize => |resize| {
                    try term.resize(resize[0], resize[1]);
                    try term.render(&app);
                },
                else => {}
            }
        }
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
                .center(&.{ .raw("Hello, Zuit!") }),
                .empty,
                .center(&.{
                    .raw("Repository: "),
                    .styled("https://github.com/Tired-Fox/zuit", .{ .fg = .green, .mod = .{ .underline = .single } })
                }),
                .center(&.{
                    .raw("Terminal API: "),
                    .styled("https://github.com/Tired-Fox/zerm", .{ .fg = .green, .mod = .{ .underline = .single } })
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
            // This is optional. Behind the scenes the allocator provided
            // to this method is an arena and is automatically cleaned up
            // after the method returns.
            //
            // The buffer holds already allocated cells that are [4]u8 and the
            // widget will copy the character data into each cell which means
            // that it is okay to deinit the data after the widget's render
            // call.
            //
            // If your priority is memory allocation then calling this after the render call
            // of the widget that uses it will be best.
            defer allo.free(text);

            try widget.Line.center(&.{ .styled(text, .{ .fg = .magenta, .mod = .{ .bold = true } }) }).render(buffer, inner);
            // try buffer.setFormatted(inner.x, inner.y, null, "{d}", .{ a.width });
        }
    }
};
