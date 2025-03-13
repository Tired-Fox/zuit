const std = @import("std");
const zerm = @import("zerm");
const zuit = @import("zuit");

const widget = zuit.widget;

const Cursor = zerm.action.Cursor;
const Screen = zerm.action.Screen;
const Capture = zerm.action.Capture;
const getTermSize = zerm.action.getTermSize;

const EventStream = zerm.event.EventStream;

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
                        .{ .code = .char('C'), .ctrl = true }
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

const a: []const u8 = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Duis viverra orci et quam blandit tempus ac accumsan turpis. Donec non magna tincidunt, semper metus a, feugiat nisi. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Quisque egestas lobortis leo quis porta. Aenean non dui lorem. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Quisque non ex dignissim, vehicula mauris non, luctus magna.";

const b: []const u8 = "Duis pellentesque, tortor a interdum eleifend, dolor justo interdum sem, sed rutrum felis ante id velit. Duis feugiat eleifend imperdiet. Integer vehicula pretium velit, non scelerisque lacus mattis sed. Donec venenatis id ligula a lobortis. Nullam quis nulla lobortis, ornare mauris sit amet, porta tellus. Suspendisse scelerisque, tortor vel blandit luctus, eros justo vehicula purus, eu egestas nulla lectus a mi. Vestibulum mollis elementum metus, eu ultrices ligula condimentum non.";

const c: [5][]const u8 = .{
    "Suspendisse turpis eros, fringilla gravida ipsum ac, ",
    "lacinia suscipit erat. Duis in faucibus",
    " leo. Cras id lorem nunc. Interdum et malesuada fames ac ante ipsum primis in faucibus. ",
    "Morbi rutrum nunc eu nulla placerat",
    ", sit amet porttitor est mollis. Nulla pretium nulla laoreet ex commodo, vel imperdiet turpis pharetra. Aenean at eros sit amet velit dignissim blandit ac sed tellus. Vestibulum sed ex neque. Praesent non libero vel nulla accumsan sollicitudin ut eget risus. Mauris iaculis suscipit sem pulvinar elementum. Aliquam auctor tristique velit, in gravida tortor cursus vitae."
};

const App = struct {
    pub fn render(area: zuit.Rect, buffer: *zuit.Buffer) !void {
        try widget.Clear.render(buffer, area);

        const v = widget.Layout(4)
            .vertical(&.{
                .{ .length = 3 },
                .{ .length = 3 },
                .{ .length = 3 },
                .{ .fill = 1 },
            })
            .split(area);

        const block_a = widget.Block.bordered();
        try block_a.render(buffer, v[0]);
        try widget.Span.styled("Start", .{ .fg = .red })
            .render(buffer, block_a.inner(v[0]));

        const block_b = widget.Block.bordered();
        try block_b.render(buffer, v[1]);

        try widget.Line.center(&.{
            .styled("｢ ", .{ .fg = .magenta }),
            .raw("Centered"),
            .styled(" ｣", .{ .fg = .red }),
        }).render(buffer, block_b.inner(v[1]));

        const block_c = widget.Block.bordered();
        try block_c.render(buffer, v[2]);

        try widget.Line.end(&.{
            .raw("End"),
        }).render(buffer, block_c.inner(v[2]));

        const block_d = widget.Block.bordered();
        try block_d.render(buffer, v[3]);

        const hl = Style{ .bg = .yellow, .fg = .black };
        try (widget.Paragraph {
            .lines = &.{
                .init(&.{ .styled(a, .{ .fg = .red }) }),
                .empty,
                .init(&.{ .raw(b) }),
                .empty,
                .init(&.{
                    .raw(c[0]), .styled(c[1], hl), .raw(c[2]),
                    .styled(c[3], hl), .raw(c[4])
                }),
            },
            .text_align = .center,
            .trim = true,
            .wrap = true,
        }).render(buffer, block_d.inner(v[3]));
    }
};
