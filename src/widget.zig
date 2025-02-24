/// Block Widget
///
/// A container that wraps a specific area. This container
/// is mainly used for displaying borders and to apply padding.
///
/// Use the `inner` method to get the wrapped area after the borders
/// and padding are applied.
pub const Block = @import("./widget/block.zig");


/// Flags to determine which borders are active/shown
pub const Borders = packed struct(u4) {
    top: bool = false,
    bottom: bool = false,
    right: bool = false,
    left: bool = false,

    /// Get the total number of cells of padding that these
    /// borders create in on the `X-axis`
    pub fn padding_x(self: *const @This()) u16 {
        return @intCast((@as(u4, @bitCast(self.*)) >> 2) & 3 - 1);
    }

    /// Get the total number of cells of padding that these
    /// borders create in on the `Left`
    pub fn padding_left(self: *const @This()) u16 {
        return @intCast((@as(u4, @bitCast(self.*)) >> 3));
    }

    /// Get the total number of cells of padding that these
    /// borders create in on the `Right`
    pub fn padding_right(self: *const @This()) u16 {
        return @intCast((@as(u4, @bitCast(self.*)) >> 2) & 1);
    }

    /// Get the total number of cells of padding that these
    /// borders create in on the `Bottom`
    pub fn padding_bottom(self: *const @This()) u16 {
        return @intCast((@as(u4, @bitCast(self.*)) >> 1) & 1);
    }

    /// Get the total number of cells of padding that these
    /// borders create in on the `Top`
    pub fn padding_top(self: *const @This()) u16 {
        return @intCast(@as(u4, @bitCast(self.*)) & 1);
    }

    /// Get the total number of cells of padding that these
    /// borders create in on the `Y-axis`
    pub fn padding_y(self: *const @This()) u16 {
        return @intCast(@as(u4, @bitCast(self.*)) & 3 - 1);
    }

    /// All sides of the border are enabled
    ///
    /// This includes `top`, `right`, `bottom`, `left`.
    pub fn all() @This() {
        return @bitCast(@as(u4, 15));
    }

    /// Check if none of the borders are active
    pub fn none(self: *const @This()) bool {
        return @as(u4, @bitCast(self)) == 0;
    }
};

/// Preconfigured border `Set` names
pub const BorderType = enum {
    Single,
    Rounded,
    Thick,
    Double,
    QuadrantInside,
    QuadrantOutside,

    /// Get the total number of preconfigured border types
    pub fn count() usize {
        return 6;
    }

    /// Get the `Set` associated with the border type
    pub fn set(self: @This()) Set {
        return switch (self) {
            .Single => Set.SINGLE,
            .Rounded => Set.ROUNDED,
            .Thick => Set.THICK,
            .Double => Set.DOUBLE,
            .QuadrantInside => Set.QUADRANT_INSIDE,
            .QuadrantOutside => Set.QUADRANT_OUTSIDE,
        };
    }
};

/// The characters that represent the different segements of a border
pub const Set = struct {
    /// Corner
    top_left: u21,
    /// Corner
    top_right: u21,
    /// Corner
    bottom_left: u21,
    /// Corner
    bottom_right: u21,
    /// Side 
    left: u21,
    /// Side 
    right: u21,
    /// Side 
    top: u21,
    /// Side 
    bottom: u21,

    pub const SINGLE: @This() = .{
        .top_left = '┌',
        .top_right = '┐',
        .bottom_left = '└',
        .bottom_right = '┘',
        .left = '│',
        .right = '│',
        .top = '─',
        .bottom = '─',
    };

    pub const ROUNDED: @This() = .{
        .top_left = '╭',
        .top_right = '╮',
        .bottom_left = '╰',
        .bottom_right = '╯',
        .left = '│',
        .right = '│',
        .top = '─',
        .bottom = '─',
    };

    pub const THICK: @This() = .{
        .top_left = '┏',
        .top_right = '┓',
        .bottom_left = '┗',
        .bottom_right = '┛',
        .left = '┃',
        .right = '┃',
        .top = '━',
        .bottom = '━',
    };

    pub const DOUBLE: @This() = .{
        .top_left = '╔',
        .top_right = '╗',
        .bottom_left = '╚',
        .bottom_right = '╝',
        .left = '║',
        .right = '║',
        .top = '═',
        .bottom = '═',
    };

    pub const QUADRANT_INSIDE: @This() = .{
        .top_left = '▗',
        .top_right = '▖',
        .bottom_left = '▝',
        .bottom_right = '▘',
        .left = '▐',
        .right = '▌',
        .top = '▄',
        .bottom = '▀',
    };

    pub const QUADRANT_OUTSIDE: @This() = .{
        .top_left = '▛',
        .top_right = '▜',
        .bottom_left = '▙',
        .bottom_right = '▟',
        .left = '▌',
        .right = '▐',
        .top = '▀',
        .bottom = '▄',
    };
};

/// Spacing on the inside of an area starting from it's edges
///
/// # Example
///
/// ```zig
/// Padding.symmetric(3, 1)
/// ```
/// ```
/// ┌─────────────┐
/// │             │ Padding:
/// │   ███████   │    left: 3
/// │   ███████   │    right: 3
/// │   ███████   │    top: 1
/// │   ███████   │    bottom: 1
/// │             │
/// └─────────────┘
/// ```
///
/// ```zig
/// Padding.proportional(1)
/// ```
/// ```
/// ┌─────────────┐
/// │             │ Padding:
/// │  █████████  │    left: 2
/// │  █████████  │    right: 2
/// │  █████████  │    top: 1
/// │  █████████  │    bottom: 1
/// │             │
/// └─────────────┘
/// ```
pub const Padding = struct {
    left: u16 = 0,
    right: u16 = 0,
    top: u16 = 0,
    bottom: u16 = 0,

    /// Apply the same padding to all sides
    pub fn uniform(size: u16) @This() {
        return .{ .left = size, .right = size, .bottom = size, .top = size };
    }

    /// Apply the same padding to both the `left` and the `right`
    pub fn horizontal(size: u16) @This() {
        return .{ .left = size, .right = size };
    }

    /// Apply the same padding to both the `top` and the `bottom`
    pub fn vertical(size: u16) @This() {
        return .{ .bottom = size, .top = size };
    }

    /// Apply the `x` padding to the `left` and `right` and the `y` padding
    /// to the `top` and `bottom`
    pub fn symmetric(x: u16, y: u16) @This() {
        return .{ .left = x, .right = x, .bottom = y, .top = y };
    }

    /// Same as `uniform` but makes the values visually proportional
    ///
    /// This means that there is a `2x` multiplier applied horizontally and `1x`
    /// multiplier vertically.
    pub fn proportional(size: u16) @This() {
        return .{ .left = size * 2, .right = size * 2, .bottom = size, .top = size };
    }

    /// Only apply the padding to the `top`
    pub fn top(size: u16) @This() { return .{ .top = size }; }
    /// Only apply the padding to the `bottom`
    pub fn bottom(size: u16) @This() { return .{ .bottom = size }; }
    /// Only apply the padding to the `left`
    pub fn left(size: u16) @This() { return .{ .left = size }; }
    /// Only apply the padding to the `right`
    pub fn right(size: u16) @This() { return .{ .right = size }; }
};
