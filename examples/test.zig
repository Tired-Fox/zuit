const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;
const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;

pub fn main() !void {
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    const area = zuit.Rect { .width = 189, .height = 44 };

    const constraints = [_]widget.Constraint{
        widget.Constraint.min(10),
        widget.Constraint.max(5),
        widget.Constraint.max(5),
        widget.Constraint.fill(2),
        widget.Constraint.fill(1),
    };

    const hoz = widget.Layout(5).horizontal(&constraints).split(area);
    for (hoz) |a| {
        std.debug.print("{any}\n", .{ a });
    }
}
