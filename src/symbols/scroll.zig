const line = @import("./line.zig");
const block = @import("./block.zig");


/// <--▮------->
/// ^  ^   ^   ^
/// │  │   │   └ end
/// │  │   └──── track
/// │  └──────── thumb
/// └─────────── begin
pub const Set = struct {
    begin: u21,
    end: u21,
    track: u21,
    thumb: u21,
};

pub const DOUBLE_VERTICAL: Set = .{
    .begin = '▲',
    .end = '▼',
    .track = line.DOUBLE_VERTICAL,
    .thumb = block.FULL,
};

pub const DOUBLE_HORIZONTAL: Set = .{
    .begin = '◄',
    .end = '►',
    .track = line.DOUBLE_HORIZONTAL,
    .thumb = block.FULL,
};

pub const VERTICAL: Set = .{
    .begin = '↑',
    .end = '↓',
    .track = line.VERTICAL,
    .thumb = block.FULL,
};

pub const HORIZONTAL: Set = .{
    .begin = '←',
    .end = '→',
    .track = line.HORIZONTAL,
    .thumb = block.FULL,
};
