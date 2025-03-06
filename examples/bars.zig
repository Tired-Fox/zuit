const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;
const symbols = zuit.symbols;

const Cursor = termz.action.Cursor;
const Screen = termz.action.Screen;
const Capture = termz.action.Capture;
const getTermSize = termz.action.getTermSize;

const EventStream = termz.event.EventStream;
const KeyCode = termz.event.KeyCode;

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
