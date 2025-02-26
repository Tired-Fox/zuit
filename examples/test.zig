const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;
const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;

pub fn main() !void {
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    const area = zuit.Rect { .width = 189, .height = 44 };

    const block = widget.Block.bordered();
    const vert = widget.Layout(3).vertical(.{
        widget.Constraint.fill(1),
        widget.Constraint.length(3),
        widget.Constraint.fill(1),
    }).split(block.inner(area));

    for (vert) |v| {
        std.debug.print("{any}\n", .{v});
    }
}
