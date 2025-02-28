const symbols = @import("../symbols.zig");

const termz = @import("termz");
const root = @import("../root.zig");

const Style = termz.style.Style;
const Buffer = root.Buffer;
const Rect = root.Rect;

const Set = symbols.scroll.Set;

pub const ScrollBar = struct {
    orientation: Orientation,
    set: ?Set = null,

    begin_style: ?Style = null,
    end_style: ?Style = null,
    track_style: ?Style = null,
    thumb_style: ?Style = null,

    pub const Orientation = enum {
        VerticalRight,
        VerticalLeft,
        HorizontalTop,
        HorizontalBottom
    };

    pub const State = struct {
        total: usize,
        position: usize,

        pub fn thumb(self: *const @This(), total: u16) Thumb {
            const size: f32 = @as(f32, @floatFromInt(total)) / @as(f32, @floatFromInt(self.total));
            const offset = size * @as(f32, @floatFromInt(self.position));

            const s: u16 = @intFromFloat(size);
            return .{
                .offset = @min(@as(u16, @intFromFloat(offset)), total - s),
                .size = s,
            };
        }

        pub const Thumb = struct {
            offset: u16,
            size: u16,
        };
    };

    pub fn renderWithState(self: *const @This(), buffer: *Buffer, area: Rect, state: *const State) !void {
        if (area.width == 0 or area.height == 0) return;

        switch (self.orientation) {
            .VerticalLeft => {
                const set = self.set orelse symbols.scroll.VERTICAL;
                const thumb = state.thumb(area.height -| 2);
                const x = area.x;

                buffer.set(x, area.y, set.begin, self.begin_style);

                var pos = area.y + 1;
                buffer.setRepeatY(x, pos, thumb.offset, set.track, self.track_style);
                pos += thumb.offset;
                buffer.setRepeatY(x, pos, thumb.size, set.thumb, self.thumb_style);
                pos += thumb.size;
                buffer.setRepeatY(x, pos, area.height -| thumb.offset -| thumb.size -| 2, set.track, self.track_style);

                buffer.set(x, area.y + area.height -| 1, set.end, self.end_style);
            },
            .VerticalRight => {
                const set = self.set orelse symbols.scroll.VERTICAL;
                const thumb = state.thumb(area.height -| 2);
                const x = area.x + area.width -| 1;

                buffer.set(x, area.y, set.begin, self.begin_style);

                var pos = area.y + 1;
                buffer.setRepeatX(x, pos, thumb.offset, set.track, self.track_style);
                pos += thumb.offset;
                buffer.setRepeatX(x, pos, thumb.size, set.thumb, self.thumb_style);
                pos += thumb.size;
                buffer.setRepeatX(x, pos, area.height -| thumb.offset -| thumb.size -| 2, set.track, self.track_style);

                buffer.set(x, area.y + area.height -| 1, set.end, self.end_style);
            },
            .HorizontalTop => {
                const set = self.set orelse symbols.scroll.HORIZONTAL;
                const thumb = state.thumb(area.width -| 2);
                const y = area.y;

                buffer.set(area.x, y, set.begin, self.begin_style);

                var pos = area.x + 1;
                buffer.setRepeatX(pos, y, thumb.offset, set.track, self.track_style);
                pos += thumb.offset;
                buffer.setRepeatX(pos, y, thumb.size, set.thumb, self.thumb_style);
                pos += thumb.size;
                buffer.setRepeatX(pos, y, area.width -| thumb.offset -| thumb.size -| 2, set.track, self.track_style);

                buffer.set(area.x + area.width -| 1, y, set.end, self.end_style);
            },
            .HorizontalBottom => {
                const set = self.set orelse symbols.scroll.HORIZONTAL;
                const thumb = state.thumb(area.width -| 2);
                const y = area.y + area.height -| 1;

                buffer.set(area.x, y, set.begin, self.begin_style);

                var pos = area.x + 1;
                buffer.setRepeatX(pos, y, thumb.offset, set.track, self.track_style);
                pos += thumb.offset;
                buffer.setRepeatX(pos, y, thumb.size, set.thumb, self.thumb_style);
                pos += thumb.size;
                buffer.setRepeatX(pos, y, area.width -| thumb.offset -| thumb.size -| 2, set.track, self.track_style);

                buffer.set(area.x + area.width -| 1, y, set.end, self.end_style);
            },
        }
    }
};
