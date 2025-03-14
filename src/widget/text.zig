const std = @import("std");
const zerm = @import("zerm");
const root = @import("../root.zig");

const Style = zerm.style.Style;
const Buffer = root.Buffer;
const Rect = root.Rect;
const Align = @import("../widget.zig").Align;

/// Optional state that can be passed to a text
/// widget to override, merge, or fallback a given
/// style
pub const TextState = struct {
    style: ?Style = null,
    method: Method = .default,

    pub const Method = enum {
        merge,
        override,
        default,
    };

    pub fn getStyle(self: *const @This(), style: ?Style) ?Style {
        switch (self.method) {
            .default => return style orelse self.style,
            .merge => return if (self.style != null and style != null)
                style.?.merge(&self.style.?)
            else
                style orelse self.style,
            .override => return self.style orelse style,
        }
    }
};

/// Used to represent a `Block`'s title
///
/// This contains the content, the style, and the position of the title
pub const Title = struct {
    text: []const u8,
    style: ?Style = null,
    position: Position = Position.top_left,

    /// Determine if the title is on the bottom border
    pub fn bottom(self: *const @This()) bool {
        return switch (self.position) {
            .bottom_left, .bottom_center, .bottom_right => true,
            else => false,
        };
    }

    /// Determine if the title is on the top border
    pub fn top(self: *const @This()) bool {
        return switch (self.position) {
            .top_left, .top_center, .top_right => true,
            else => false,
        };
    }

    /// Determine of the title is left aligned
    pub fn left(self: *const @This()) bool {
        return switch (self.position) {
            .top_left, .bottom_left => true,
            else => false,
        };
    }

    /// Determine of the title is center aligned
    pub fn center(self: *const @This()) bool {
        return switch (self.position) {
            .top_center, .bottom_center => true,
            else => false,
        };
    }

    /// Determine of the title is right aligned
    pub fn right(self: *const @This()) bool {
        return switch (self.position) {
            .top_right, .bottom_right => true,
            else => false,
        };
    }

    /// Location where the title is in a `Block`
    pub const Position = enum {
        top_left,
        top_center,
        top_right,
        bottom_left,
        bottom_center,
        bottom_right,
    };

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        try self.renderWithState(buffer, area, .{});
    }

    pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: TextState) !void {
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
            .top_left => buffer.setSlice(area.x, area.y, self.text[0..@min(self.text.len, area.width -| 1)], state.getStyle(self.style)),
            .top_center => {
                const x = @divFloor(area.width, 2) -| @divFloor(@as(u16, @intCast(self.text.len)), 2);
                buffer.setSlice(area.x + x, area.y, self.text[0..@min(self.text.len, area.width -| 1)], state.getStyle(self.style));
            },
            .top_right => {
                const x = area.width -| @as(u16, @intCast(self.text.len));
                buffer.setSlice(area.x + x, area.y, self.text[0..@min(self.text.len, area.width -| 1)], state.getStyle(self.style));
            },
            .bottom_left => {
                const y = area.y + area.height -| 1;
                buffer.setSlice(area.x, y, self.text[0..@min(self.text.len, area.width -| 1)], state.getStyle(self.style));
            },
            .bottom_center => {
                const x = @divFloor(area.width, 2) -| @divFloor(@as(u16, @intCast(self.text.len)), 2);
                const y = area.y + area.height -| 1;
                buffer.setSlice(area.x + x, y, self.text[0..@min(self.text.len, area.width -| 1)], state.getStyle(self.style));
            },
            .bottom_right => {
                const x = area.width -| @as(u16, @intCast(self.text.len));
                const y = area.y + area.height -| 1;
                buffer.setSlice(area.x + x, y, self.text[0..@min(self.text.len, area.width -| 1)], state.getStyle(self.style));
            },
        }
    }
};

/// A styled `span` of text
pub const Span = struct {
    text: []const u8,
    style: ?Style = null,

    pub fn raw(text: []const u8) @This() {
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
        try self.renderWithState(buffer, area, .{});
    }

    pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: TextState) !void {
        if (area.width == 0 or area.height == 0) return;
        const max: usize = @intCast(area.width);

        var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = self.text };
        var i: usize = 0;
        while (iter.nextCodepoint()) |codepoint| : (i += 1) {
            if (i >= max) break;
            buffer.set(area.x + @as(u16, @intCast(i)), area.y, codepoint, state.getStyle(self.style));
        }
    }
};

/// An aligned collection of `Span`s that can be trimmed taking up an entire row
pub const Line = struct {
    spans: []const Span,
    text_align: ?Align = null,
    style: ?Style = null,
    trim: bool = false,

    pub const empty: @This() = .{ .spans = &.{} };

    /// Collect the provided spans and apply the default alignment
    pub fn init(spans: []const Span) @This() {
        return .{ .spans = spans };
    }

    /// Collect the provided spans and apply the `start` alignment
    pub fn start(spans: []const Span) @This() {
        return .{ .spans = spans, .text_align = .start };
    }

    /// Collect the provided spans and apply the `center` alignment
    pub fn center(spans: []const Span) @This() {
        return .{ .spans = spans, .text_align = .center };
    }

    /// Collect the provided spans and apply the `end` alignment
    pub fn end(spans: []const Span) @This() {
        return .{ .spans = spans, .text_align = .end };
    }

    /// Utf8 codepoint length of the full line of text
    pub fn len(self: *const @This()) usize {
        var length: usize = 0;
        for (self.spans) |span| length += span.len();
        return length;
    }

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        try self.renderWithState(buffer, area, .{});
    }

    pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: TextState) !void {
        if (area.width == 0 or area.height == 0) return;
        switch (self.text_align orelse Align.start) {
            .start => {
                // Truncate the end
                var x: u16 = area.x;
                for (self.spans, 0..) |item, i| {
                    const max: usize = @intCast(area.x + area.width);

                    const text = if (self.trim and i == 0)
                        std.mem.trimLeft(u8, item.text, &std.ascii.whitespace)
                    else item.text;
                    var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
                    while (iter.nextCodepoint()) |codepoint| : (x +|= 1) {
                        if (x > max) break;
                        buffer.set(x, area.y, codepoint, state.getStyle(item.style orelse self.style));
                    }

                    if (x >= max) break;
                }
            },
            .center => {
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
                        buffer.set(area.x + x, area.y, codepoint, state.getStyle(item.style orelse self.style));
                        x +|= 1;
                        e -|= 1;
                    }
                }
            },
            .end => {
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
                            buffer.set(area.x + a, area.y, codepoint, state.getStyle(item.style orelse self.style));
                        }
                    } else {
                        var a: u16 = 0;
                        x -|= @intCast(size);
                        while (iter.nextCodepoint()) |codepoint| : (a += 1) {
                            buffer.set(area.x + x + a, area.y, codepoint, state.getStyle(item.style orelse self.style));
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

/// Collection of aligned lines that could possibly wrap when they get too long
///
/// Also provides overrides for trim, alignment, and styling if the line does not
/// have it defined.
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
    /// Default alignment that is applied to a line if it uses the default alignment
    text_align: ?Align = null,
    /// Default style that is applied to a line if it does not have styling
    style: ?Style = null,

    pub fn render(self: *const @This(), buffer: *Buffer, area: Rect) !void {
        if (area.width == 0 or area.height == 0) return;
        var pos = area;
        if (self.wrap) {
            outer: for (self.lines) |line| {
                if (line.spans.len == 0) {
                    pos.y = @min(pos.y + 1, area.y + pos.height);
                    if (pos.y == area.y + pos.height) break
                    else continue;
                }

                var iter = LineIter.init(
                    &Line {
                        .spans = line.spans,
                        .style = line.style orelse self.style,
                        .text_align = line.text_align orelse self.text_align,
                        .trim = line.trim or self.trim
                    },
                    @intCast(area.width)
                );
                while (iter.next()) |item| {
                    try item.render(buffer, pos);
                    pos.y = @min(pos.y + 1, area.y + pos.height);
                    if (pos.y == area.y + pos.height) break :outer;
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

/// Iterator to chunk up individual lines into multiple wrapped lines
const LineIter = struct {
    span: usize = 0,
    i: usize = 0,
    w:  usize = 0,

    max: usize,
    size: usize,
    line: *const Line,

    pub fn init(line: *const Line, max: usize) @This() {
        return .{
            .size = line.len(),
            .line = line,
            .max = max,
        };
    }

    pub fn next(self: *@This()) ?Chunk {
        if (self.span >= self.line.spans.len) return null;

        const start = self.span;
        var offset_start = self.i;

        width_loop: while (self.w < self.max and self.span < self.line.spans.len) {
            const span = self.line.spans[self.span];
            var text = span.text[self.i..];

            const trimmed = std.mem.trimLeft(u8, text, &std.ascii.whitespace);
            if (trimmed.len != text.len) {
                self.i += text.len - trimmed.len;
                offset_start = self.i;
                text = trimmed;
            }

            var iter = std.unicode.Utf8Iterator { .i = 0, .bytes = text };
            while (iter.nextCodepointSlice()) |_| {
                self.w += 1;
                if (self.w >= self.max) {
                    self.i += iter.i;
                    if (self.i >= span.text.len) break;
                    break :width_loop;
                }
            }
            self.i = 0;
            self.span = @min(self.span + 1, self.line.spans.len);
        }
        self.w = 0;

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
            switch (self.line.text_align orelse Align.start) {
                .start => {
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
                .center => {
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
                .end => {
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
