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

                    if (key.matches(.{ .code = .down, .kind = .press })) {
                        app.list_state = @min(app.list_state + 1, 7);
                    }
                    if (key.matches(.{ .code = .up, .kind = .press })) {
                        app.list_state -|= 1;
                    }

                    // left
                    if (key.matches(.{ .code = .char('h'), .kind = .press })) {
                        if (app.table_state.column) |*ts| {
                            ts.* -|= 1;
                        } else {
                            app.table_state.column = 2;
                        }
                    }
                    // down
                    if (key.matches(.{ .code = .char('j'), .kind = .press })) {
                        app.table_state.row = @min(app.table_state.row + 1, 3);
                    }
                    // up
                    if (key.matches(.{ .code = .char('k'), .kind = .press })) {
                        app.table_state.row -|= 1;
                    }
                    // right
                    if (key.matches(.{ .code = .char('l'), .kind = .press })) {
                        if (app.table_state.column) |*ts| {
                            ts.* = @min(ts.* + 1, 2);
                        } else {
                            app.table_state.column = 0;
                        }
                    }
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
    list_state: usize = 0,
    table_state: widget.TableState = .{},

    pub fn render(self: *const @This(), buffer: *zuit.Buffer, area: zuit.Rect) !void {
        try widget.Clear.render(buffer, area);
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
            .footer = .{
                .columns = .{ .start(&.{ .raw("Updated Dec 28") }), .empty, .empty }
            },
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
