const std = @import("std");
const termz = @import("termz");
const root = @import("../root.zig");

const Style = termz.style.Style;
const Buffer = root.Buffer;
const Rect = root.Rect;
const Align = @import("../widget.zig").Align;

pub const Title = struct {
    text: []const u8,
    style: ?Style = null,
    position: Position = Position.TopLeft,

    pub fn bottom(self: *const @This()) bool {
        return switch (self.position) {
            .BottomLeft, .BottomCenter, .BottomRight => true,
            else => false,
        };
    }

    pub fn top(self: *const @This()) bool {
        return switch (self.position) {
            .TopLeft, .TopCenter, .TopRight => true,
            else => false,
        };
    }

    pub fn left(self: *const @This()) bool {
        return switch (self.position) {
            .TopLeft, .BottomLeft => true,
            else => false,
        };
    }

    pub fn center(self: *const @This()) bool {
        return switch (self.position) {
            .TopCenter, .BottomCenter => true,
            else => false,
        };
    }

    pub fn right(self: *const @This()) bool {
        return switch (self.position) {
            .TopRight, .BottomRight => true,
            else => false,
        };
    }

    pub const Position = enum {
        TopLeft,
        TopCenter,
        TopRight,
        BottomLeft,
        BottomCenter,
        BottomRight,
    };

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        // Renders and specific location regardless of border or other context
        // TopLeft────────────TopCenter───────────TopRight
        // │                                             │
        // │                                             │
        // │                                             │
        // │                                             │
        // │                                             │
        // │                                             │
        // BottomLeft───────BottomCenter───────BottomRight
        switch(self.position) {
            .TopLeft => try buffer.setSlice(area.x, area.y, self.text[0..@min(self.text.len, area.width -| 1)], self.style),
            .TopCenter => {
                const x = @divFloor(area.width, 2) -| @divFloor(@as(u16, @intCast(self.text.len)), 2);
                try buffer.setSlice(x, 0, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .TopRight => {
                const x = area.width -| @as(u16, @intCast(self.text.len));
                try buffer.setSlice(x, 0, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .BottomLeft => {
                const y = area.y + area.height -| 1;
                try buffer.setSlice(area.x, y, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .BottomCenter => {
                const x = @divFloor(area.width, 2) -| @divFloor(@as(u16, @intCast(self.text.len)), 2);
                const y = area.y + area.height -| 1;
                try buffer.setSlice(x, y, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .BottomRight => {
                const x = area.width -| @as(u16, @intCast(self.text.len));
                const y = area.y + area.height -| 1;
                try buffer.setSlice(x, y, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
        }
    }
};

/// Represents a possibly styled slice of text
pub const Span = struct {
    text: []const u8,
    style: ?Style = null,

    pub fn init(text: []const u8) @This() {
        return .{ .text = text };
    }

    pub fn styled(text: []const u8, style: Style) @This() {
        return .{ .text = text, .style = style };
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        const max: usize = @intCast(area.width);

        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = self.text };
        var i: usize = 0;
        while (iter.nextCodepoint()) |codepoint| : (i += 1) {
            if (i >= max) break;
            try buffer.set(area.x + @as(u16, @intCast(i)), area.y, codepoint, self.style);
        }
    }
};

/// Represents a list of `Span`'s that when combine form a full with single line
///
/// The line may also align it's text content.
pub const Line = struct {
    spans: []const Span,
    text_align: ?Align = null,
    style: ?Style = null,

    pub fn init(spans:  []const Span) @This() {
        return .{ .spans = spans };
    }

    pub fn start(spans:  []const Span) @This() {
        return .{ .spans = spans, .text_align = .Start };
    }

    pub fn center(spans:  []const Span) @This() {
        return .{ .spans = spans, .text_align = .Center };
    }

    pub fn end(spans:  []const Span) @This() {
        return .{ .spans = spans, .text_align = .End };
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        switch (self.text_align orelse Align.Start) {
            .Start => {
                // Truncate the end
                var x: u16 = area.x;
                for (self.spans) |item| {
                    const max: usize = @intCast(area.width);

                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = item.text };
                    while (iter.nextCodepoint()) |codepoint| : (x +|= 1) {
                        if (x > max) break;
                        try buffer.set(x, area.y, codepoint, item.style orelse self.style);
                    }

                    if (x >= max) break;
                }
            },
            .Center => {
                // Truncate the both ends along will adding an x offset to center text
                var total: usize = 0;
                for (self.spans) |item| total +|= utf8Length(item.text);

                var offset: usize = 0;
                if (total > @as(usize, @intCast(area.width))) {
                    offset = @divFloor(total -| @as(usize, @intCast(area.width)), 2);
                }

                var x: u16 = 0;
                if (total < @as(usize, @intCast(area.width))) {
                    x +|= @divFloor(area.width -| @as(u16, @intCast(total)), 2);
                }

                for (self.spans) |item| {
                    var size = utf8Length(item.text);
                    if (size <= offset) {
                        offset -= size;
                        continue;
                    }

                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = item.text };
                    if (offset > 0) {
                        for (0..offset) |_| {
                            _ = iter.nextCodepointSlice();
                        }
                        size -= offset;
                        offset = 0;
                    }

                    var e: usize = size;
                    if (x +| size > area.width) {
                        e -|= (x +| size) -| (area.width);
                    }

                    const max: usize = @intCast(area.width);
                    while (iter.nextCodepoint()) |codepoint| {
                        if (x > max or e == 0) break;
                        try buffer.set(area.x + x, area.y, codepoint, item.style orelse self.style);
                        x +|= 1;
                        e -|= 1;
                    }
                }
            },
            .End => {
                // Truncate the beginning and push to the end of the line
                var x: u16 = area.width;
                var i: usize = self.spans.len - 1;

                while (true) : (i -= 1) {
                    const item = self.spans[i];
                    const size = utf8Length(item.text);

                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = item.text };
                    const skip = if (@as(u16, @intCast(size)) > x) @as(u16, @intCast(size)) -| x else 0;

                    if (skip > 0) {
                        for (0..skip) |_| { _ = iter.nextCodepointSlice(); }
                        x = 0;
                        var a: u16 = 0;
                        while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                            try buffer.set(area.x + a, area.y, codepoint, item.style orelse self.style);
                        }
                    } else {
                        var a: u16 = 0;
                        x -|= @intCast(size);
                        while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                            try buffer.set(area.x + x + a, area.y, codepoint, item.style orelse self.style);
                        }
                    }

                    if (x == 0 or i == 0) break;
                }
            },
        }
    }
};

fn utf8Length(buffer: []const u8) usize {
    var length: usize = 0;
    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = buffer };
    while (iter.nextCodepoint()) |_| length += 1;
    return length;
}

/// Represents a list of `Span`'s that when combine form a full with single line
///
/// The line may also align it's text content.
pub const Paragraph = struct {
    lines: []const Line,
    /// When a line is too long it will be split to create a new line
    /// instead of truncating.
    wrap: bool = false,
    /// Trim each lines whitespace
    ///
    /// This removes these characters from the calculation for wrapping
    /// and truncating.
    trim: bool = false,
    text_align: Align = .Start,
    style: ?Style = null,

    pub fn init(lines: []const Line) @This() {
        return .{ .lines = lines };
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        _ = self;
        _ = buffer;
        _ = area;
        // Render each line same way that lines render except if
        // the line is longer and wrap is on; then it attempts to split on
        // whitespace characters and render the remaining spans on the next
        // line
        //
        // When a span contains a whitespace and needs to be split it
        // will create new spans with the same styling with the split/sliced
        // portions of the parent span.
        //
        // In cases where a single word is left then it will attempt to split after
        // non alphabetical characters (0-9 and symbols). Last resort would be to split
        // the word at the max length. This could open the way for words to be split
        // with an appropriate algorith and add a hyphen for words that continue.
        //
        // Assume lines are 12 wide.
        // Paragraph[ Line[ Span["Hello!"], Span[" How are you doing today?"] ] ]
        // ***
        // Paragraph[ Line[ Span["Hello!"], Span["How"] ], Line[ Span["are you"] ], Line[ Span["doing today?"] ] ]
        //
        // Hello! How are you today?
        // ***
        // Hello! How
        // are you 
        // doing today?
    }
};
