const symbols = @import("../symbols/border.zig");
const Set = symbols.Set;

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
