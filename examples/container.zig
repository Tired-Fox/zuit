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

                    if (key.match(.{ .code = .down })) {
                        app.list_state = @min(app.list_state + 1, 7);
                        try term.render(&app);
                    }
                    if (key.match(.{ .code = .up })) {
                        app.list_state -|= 1;
                        try term.render(&app);
                    }

                    // left
                    if (key.match(.{ .code = .char('h') })) {
                        if (app.table_state.column) |*ts| {
                            ts.* -|= 1;
                        } else {
                            app.table_state.column = 2;
                        }
                        try term.render(&app);
                    }
                    // down
                    if (key.match(.{ .code = .char('j') })) {
                        app.table_state.row = @min(app.table_state.row + 1, 3);
                        try term.render(&app);
                    }
                    // up
                    if (key.match(.{ .code = .char('k') })) {
                        app.table_state.row -|= 1;
                        try term.render(&app);
                    }
                    // right
                    if (key.match(.{ .code = .char('l') })) {
                        if (app.table_state.column) |*ts| {
                            ts.* = @min(ts.* + 1, 2);
                        } else {
                            app.table_state.column = 0;
                        }
                        try term.render(&app);
                    }
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
    list_state: usize = 0,
    table_state: widget.TableState = .{},

    pub fn render(self: *const @This(), buffer: *zuit.Buffer, area: zuit.Rect) !void {
        const vert = widget.Layout(2).vertical(&.{
            .{ .fill = 1 },
            .{ .fill = 1 },
        }).split(area);

        const list = widget.List {
            .items = &.{
                .start(&.{ .raw("Line 1") }),
                .start(&.{ .raw("Line 2") }),
                .start(&.{ .raw("Line 3") }),
                .start(&.{ .raw("Line 4") }),
                .start(&.{ .raw("Line 5") }),
                .start(&.{ .raw("Line 6") }),
                .start(&.{ .raw("Line 7") }),
                .start(&.{ .raw("Line 8") }),
            },
            .highlight_style = .{ .bg = .yellow, .fg = .black },
            .highlight_symbol = ">",
        };
        try list.renderWithState(buffer, vert[0], self.list_state);

        const table = widget.Table(3) {
            .constraints = @splat(.{ .fill = 1 }),
            .header = .{
                .columns = .{ .start(&.{ .raw("Left") }), .center(&.{ .raw("Middle") }), .end(&.{ .raw("Right") }) },
                .margin = .{ .bottom = 1 },
            },
            .footer = .raw(.{ .start(&.{ .raw("Table Footer") }), .empty, .empty }),
            .rows = &.{
                .raw(.{ .start(&.{ .raw("a") }), .center(&.{ .raw("b") }), .end(&.{ .raw("c") }) }),
                .{
                    .columns = .{ .start(&.{ .raw("d") }), .center(&.{ .raw("e") }), .end(&.{ .raw("f") }) },
                    .margin = .symmetric(1),
                },
                .raw(.{ .start(&.{ .raw("g") }), .center(&.{ .raw("h") }), .end(&.{ .raw("i") }) }),
                .raw(.{ .start(&.{ .raw("j") }), .center(&.{ .raw("k") }), .end(&.{ .raw("l") }) })
            },
            .style = .{ .fg = .blue },
            .row_highlight_style = .{ .bg = .xterm(.grey_7) },
            .column_highlight_style = .{ .bg = .xterm(.grey_7) },
            .cell_highlight_style = .{ .bg = .xterm(.grey_19) }
        };

        // try table.render(buffer, vert[1]);
        try table.renderWithState(buffer, vert[1], &self.table_state);
    }
};
