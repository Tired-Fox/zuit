const std = @import("std");
const termz = @import("termz");
const zuit = @import("zuit");

const widget = zuit.widget;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;
const execute = termz.execute;

pub fn main() !void {
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    const area = zuit.Rect { .width = 24, .height = 80 };
    const layout = widget.Layout(5).horizontal(.{
        widget.Constraint.min(10),
        widget.Constraint.max(5),
        widget.Constraint.max(5),
        widget.Constraint.fill(2),
        widget.Constraint.fill(1),
    });

    for (layout.split(area), 0..) |a, i| {
        std.debug.print("{d}. {any} @ {any}\n", .{ i + 1, layout.constraints[i], a });
    }
}
