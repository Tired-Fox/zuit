const std = @import("std");
const zerm = @import("zerm");
const zuit = @import("zuit");

const widget = zuit.widget;
const symbols = zuit.symbols;

const Cursor = zerm.action.Cursor;
const Screen = zerm.action.Screen;
const Capture = zerm.action.Capture;
const getTermSize = zerm.action.getTermSize;

const EventStream = zerm.event.EventStream;
const KeyCode = zerm.event.KeyCode;

const Style = zerm.style.Style;

const Utf8ConsoleOutput = zerm.Utf8ConsoleOutput;
const execute = zerm.execute;

fn setup() !void {
    try Screen.enableRawMode();
    try execute(.stdout, .{
        Screen.enter_alternate_buffer,
        Cursor { .col = 1, .row = 1, .visibility = .hidden },
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
                        .{ .code = .char('q') },
                        .{ .code = .char('c'), .ctrl = true },
                        .{ .code = .char('C'), .ctrl = true },
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
    pub fn render(buffer: *zuit.Buffer, area: zuit.Rect) !void {
        try widget.Clear.render(buffer, area);
        const vert = widget.Layout(4).vertical(&.{
            .{ .length = 1 },
            .{ .length = 10 },
            .{ .length = 1 },
            .{ .length = 3 },
        }).split(area);

        const lg = widget.LineGauge {
            .progress = 0.5,
            .set = .{ .horizontal = '█' },
            .filled_style = .{ .fg = .green },
            .unfilled_style = .{ .fg = .rgb(10, 20, 30) },
        };
        try lg.render(buffer, vert[0]);

        const g = widget.Gauge {
            .progress = 0.5,
            .filled_style = .{ .fg = .black, .bg = .red },
            .unfilled_style = .{ .fg = .red },
        };
        try g.render(buffer, vert[1]);

        var ss = widget.ScrollBar.State {
            .total = 10,
            .position = 6,
        };

        const sb = widget.ScrollBar {
            .orientation = .HorizontalTop,
        };
        try sb.renderWithState(buffer, vert[2], &ss);
    }
};
