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
        if (area.width == 0 or area.height == 0) return;
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
            .TopLeft => buffer.setSlice(area.x, area.y, self.text[0..@min(self.text.len, area.width -| 1)], self.style),
            .TopCenter => {
                const x = @divFloor(area.width, 2) -| @divFloor(@as(u16, @intCast(self.text.len)), 2);
                buffer.setSlice(x, 0, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .TopRight => {
                const x = area.width -| @as(u16, @intCast(self.text.len));
                buffer.setSlice(x, 0, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .BottomLeft => {
                const y = area.y + area.height -| 1;
                buffer.setSlice(area.x, y, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .BottomCenter => {
                const x = @divFloor(area.width, 2) -| @divFloor(@as(u16, @intCast(self.text.len)), 2);
                const y = area.y + area.height -| 1;
                buffer.setSlice(x, y, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
            },
            .BottomRight => {
                const x = area.width -| @as(u16, @intCast(self.text.len));
                const y = area.y + area.height -| 1;
                buffer.setSlice(x, y, self.text[0..@min(self.text.len, area.width -| 1)], self.style);
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

    /// Utf8 codepoint length of the span of text
    pub fn len(self: *const @This()) usize {
        return utf8Length(self.text);
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.width == 0 or area.height == 0) return;
        const max: usize = @intCast(area.width);

        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = self.text };
        var i: usize = 0;
        while (iter.nextCodepoint()) |codepoint| : (i += 1) {
            if (i >= max) break;
            buffer.set(area.x + @as(u16, @intCast(i)), area.y, codepoint, self.style);
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
    trim: bool = false,

    pub fn init(spans: []const Span) @This() {
        return .{ .spans = spans };
    }

    pub fn start(spans: []const Span) @This() {
        return .{ .spans = spans, .text_align = .Start };
    }

    pub fn center(spans: []const Span) @This() {
        return .{ .spans = spans, .text_align = .Center };
    }

    pub fn end(spans: []const Span) @This() {
        return .{ .spans = spans, .text_align = .End };
    }

    pub fn empty() @This() {
        return .{ .spans = &.{} };
    }

    /// Utf8 codepoint length of the full line of text
    pub fn len(self: *const @This()) usize {
        var length: usize = 0;
        for (self.spans) |span| length += span.len();
        return length;
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.width == 0 or area.height == 0) return;
        switch (self.text_align orelse Align.Start) {
            .Start => {
                // Truncate the end
                var x: u16 = area.x;
                for (self.spans, 0..) |item, i| {
                    const max: usize = @intCast(area.width);

                    const text = if (self.trim and i == 0) std.mem.trimLeft(u8, item.text, &std.ascii.whitespace) else item.text;
                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
                    while (iter.nextCodepoint()) |codepoint| : (x +|= 1) {
                        if (x > max) break;
                        buffer.set(x, area.y, codepoint, item.style orelse self.style);
                    }

                    if (x >= max) break;
                }
            },
            .Center => {
                // Truncate the both ends along will adding an x offset to center text
                var total: usize = 0;
                for (self.spans, 0..) |item, i| {
                    var text = item.text;
                    if (self.trim and i == 0) text = std.mem.trimLeft(u8, text, &std.ascii.whitespace);
                    if (self.trim and i == self.spans.len - 1) text = std.mem.trimRight(u8, text, &std.ascii.whitespace);
                    total +|= utf8Length(text);
                }

                var offset: usize = 0;
                if (total > @as(usize, @intCast(area.width))) {
                    offset = @divFloor(total -| @as(usize, @intCast(area.width)), 2);
                }

                var x: u16 = 0;
                if (total < @as(usize, @intCast(area.width))) {
                    x +|= @divFloor(area.width -| @as(u16, @intCast(total)), 2);
                }

                for (self.spans, 0..) |item, i| {
                    var text = item.text;
                    if (self.trim and i == 0) text = std.mem.trimLeft(u8, text, &std.ascii.whitespace);
                    if (self.trim and i == self.spans.len - 1) text = std.mem.trimRight(u8, text, &std.ascii.whitespace);

                    var size = utf8Length(text);
                    if (size <= offset) {
                        offset -= size;
                        continue;
                    }

                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
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
                        buffer.set(area.x + x, area.y, codepoint, item.style orelse self.style);
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
                    const text = if (self.trim and i == self.spans.len - 1) std.mem.trimRight(u8, item.text, &std.ascii.whitespace) else item.text;

                    const size = utf8Length(text);

                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
                    const skip = if (@as(u16, @intCast(size)) > x) @as(u16, @intCast(size)) -| x else 0;

                    if (skip > 0) {
                        for (0..skip) |_| { _ = iter.nextCodepointSlice(); }
                        x = 0;
                        var a: u16 = 0;
                        while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                            buffer.set(area.x + a, area.y, codepoint, item.style orelse self.style);
                        }
                    } else {
                        var a: u16 = 0;
                        x -|= @intCast(size);
                        while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                            buffer.set(area.x + x + a, area.y, codepoint, item.style orelse self.style);
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
    text_align: ?Align = null,
    style: ?Style = null,

    pub fn init(value: anytype) @This() {
        return .{ .lines = value };
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.width == 0 or area.height == 0) return;
        var pos = area;
        if (self.wrap) {
            outer: for (self.lines) |line| {
                const l = Line {
                    .spans = line.spans,
                    .style = line.style orelse self.style,
                    .text_align = line.text_align orelse self.text_align,
                    .trim = line.trim or self.trim
                };

                var iter = chunk(&l, @intCast(area.width));
                while (iter.next()) |item| {
                    try item.render(buffer, pos);
                    pos.y = @min(pos.y + 1, pos.height);
                    if (pos.y == pos.height) break :outer;
                }
            }
        } else {
            for (self.lines) |line| {
                const l = Line {
                    .spans = line.spans,
                    .style = line.style orelse self.style,
                    .text_align = line.text_align orelse self.text_align,
                    .trim = line.trim or self.trim
                };
                try l.render(buffer, pos);

                pos.y = @min(pos.y + 1, pos.height);
                if (pos.y == pos.height) break;
            }
        }
    }
};

const LinkChunkIter = struct {
    span: usize = 0,
    i: usize = 0,
    w:  usize = 0,

    max: usize,
    size: usize,
    line: *const Line,

    /// Returns a tuple of { start, end, line }
    /// 
    /// The line has spans that are a slice into the original line.
    /// start and end are the offsets from the first and last span representing
    /// splits of the original line.
    pub fn next(self: *@This()) ?Chunk {
        if (self.span >= self.line.spans.len) return null;

        const start = self.span;
        var offset_start = self.i;

        width_loop: while (self.w < self.max and self.span < self.line.spans.len) {
            const text = self.line.spans[self.span].text;

            // TODO: IF first span and trim is enabled
            //       THEN trim the whitespace from the start
            if (self.span == start and self.line.trim and self.i == 0) {
                self.i += text.len - std.mem.trimLeft(u8, text, &std.ascii.whitespace).len;
                offset_start = self.i;
            }

            var iter = std.unicode.Utf8Iterator { .i = self.i, .bytes = text };
            while (iter.nextCodepointSlice()) |_| {
                self.w += 1;
                if (self.w >= self.max) {
                    self.i = iter.i;
                    if (self.i == text.len) break;
                    break :width_loop;
                }
            }
            self.i = 0;
            self.span = @min(self.span + 1, self.line.spans.len);
        }
        self.w = 0;

        // TODO: IF last span and trim is enabled
        //       THEN trim the whitespace from the end
        var offset_end = self.i;
        const spans = self.line.spans[start..if (offset_end > 0) self.span + 1 else self.span];
        if (self.line.trim and offset_end > 0) {
            const e = std.mem.trimRight(u8, spans[spans.len-1].text[0..offset_end], &std.ascii.whitespace).len;
            if (e != offset_end) offset_end = e;
        }

        return .{
            .start = offset_start,
            .end = offset_end,
            .line = .{
                .spans = spans,
                .trim = self.line.trim,
                .style = self.line.style,
                .text_align = self.line.text_align
            },
        };
    }

    pub const Chunk = struct {
        start: usize,
        end: usize,
        line: Line,

        pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
            if (area.width == 0 or area.height == 0) return;
            switch (self.line.text_align orelse Align.Start) {
                .Start => {
                    // Truncate the end
                    var x: u16 = area.x;
                    for (self.line.spans, 0..) |item, i| {
                        const max: usize = @intCast(area.width);

                        var text = item.text;
                        if (self.start > 0 and i == 0) text = text[self.start..];
                        if (self.end > 0 and i == self.line.spans.len - 1) text = text[0..self.end];

                        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
                        while (iter.nextCodepoint()) |codepoint| : (x +|= 1) {
                            if (x > max) break;
                            buffer.set(x, area.y, codepoint, item.style orelse self.line.style);
                        }

                        if (x >= max) break;
                    }
                },
                .Center => {
                    // Truncate the both ends along will adding an x offset to center text
                    var total: usize = 0;
                    for (self.line.spans, 0..) |item, i| {
                        var text = item.text;
                        if (self.start > 0 and self.end > 0 and i == 0 and i == self.line.spans.len - 1) text = text[self.start..self.end]
                        else if (self.start > 0 and i == 0) text = text[self.start..]
                        else if (self.end > 0 and i == self.line.spans.len - 1) text = text[0..self.end];

                        total +|= utf8Length(text);
                    }

                    var offset: usize = 0;
                    if (total > @as(usize, @intCast(area.width))) {
                        offset = @divFloor(total -| @as(usize, @intCast(area.width)), 2);
                    }

                    var x: u16 = 0;
                    if (total < @as(usize, @intCast(area.width))) {
                        x +|= @divFloor(area.width -| @as(u16, @intCast(total)), 2);
                    }

                    for (self.line.spans, 0..) |item, i| {
                        var text = item.text;
                        if (self.start > 0 and self.end > 0 and i == 0 and i == self.line.spans.len - 1) text = text[self.start..self.end]
                        else if (self.start > 0 and i == 0) text = text[self.start..]
                        else if (self.end > 0 and i == self.line.spans.len - 1) text = text[0..self.end];

                        var size = utf8Length(text);
                        if (size <= offset) {
                            offset -= size;
                            continue;
                        }

                        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
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
                            buffer.set(area.x + x, area.y, codepoint, item.style orelse self.line.style);
                            x +|= 1;
                            e -|= 1;
                        }
                    }
                },
                .End => {
                    // Truncate the beginning and push to the end of the line
                    var x: u16 = area.width;
                    var i: usize = self.line.spans.len - 1;

                    while (true) : (i -= 1) {
                        const item = self.line.spans[i];
                        var text = item.text;
                        if (self.start > 0 and i == 0) text = text[self.start..];
                        if (self.end > 0 and i == self.line.spans.len - 1) text = text[0..self.end];

                        const size = utf8Length(text);

                        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
                        const skip = if (@as(u16, @intCast(size)) > x) @as(u16, @intCast(size)) -| x else 0;

                        if (skip > 0) {
                            for (0..skip) |_| { _ = iter.nextCodepointSlice(); }
                            x = 0;
                            var a: u16 = 0;
                            while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                                buffer.set(area.x + a, area.y, codepoint, item.style orelse self.line.style);
                            }
                        } else {
                            var a: u16 = 0;
                            x -|= @intCast(size);
                            while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                                buffer.set(area.x + x + a, area.y, codepoint, item.style orelse self.line.style);
                            }
                        }

                        if (x == 0 or i == 0) break;
                    }
                },
            }
        }
    };
};

fn chunk(line: *const Line, max: usize) LinkChunkIter {
    return .{
        .size = line.len(),
        .line = line,
        .max = max,
    };
}
