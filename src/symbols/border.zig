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
};

pub const SINGLE_TOP_LEFT: u21 = '┌';
pub const SINGLE_TOP_RIGHT: u21 = '┐';
pub const SINGLE_BOTTOM_LEFT: u21 = '└';
pub const SINGLE_BOTTOM_RIGHT: u21 = '┘';
pub const SINGLE_LEFT: u21 = '│';
pub const SINGLE_RIGHT: u21 = '│';
pub const SINGLE_TOP: u21 = '─';
pub const SINGLE_BOTTOM: u21 = '─';

pub const SINGLE: Set = .{
    .top_left = SINGLE_TOP_LEFT,
    .top_right = SINGLE_TOP_RIGHT,
    .bottom_left = SINGLE_BOTTOM_LEFT,
    .bottom_right = SINGLE_BOTTOM_RIGHT,
    .left = SINGLE_LEFT,
    .right = SINGLE_RIGHT,
    .top = SINGLE_TOP,
    .bottom = SINGLE_BOTTOM,
};

pub const ROUNDED_TOP_LEFT: u21 = '╭';
pub const ROUNDED_TOP_RIGHT: u21 = '╮';
pub const ROUNDED_BOTTOM_LEFT: u21 = '╰';
pub const ROUNDED_BOTTOM_RIGHT: u21 = '╯';
pub const ROUNDED_LEFT: u21 = '│';
pub const ROUNDED_RIGHT: u21 = '│';
pub const ROUNDED_TOP: u21 = '─';
pub const ROUNDED_BOTTOM: u21 = '─';

pub const ROUNDED: Set = .{
    .top_left = ROUNDED_TOP_LEFT,
    .top_right = ROUNDED_TOP_RIGHT,
    .bottom_left = ROUNDED_BOTTOM_LEFT,
    .bottom_right = ROUNDED_BOTTOM_RIGHT,
    .left = ROUNDED_LEFT,
    .right = ROUNDED_RIGHT,
    .top = ROUNDED_TOP,
    .bottom = ROUNDED_BOTTOM,
};

pub const THICK_TOP_LEFT: u21 = '┏';
pub const THICK_TOP_RIGHT: u21 = '┓';
pub const THICK_BOTTOM_LEFT: u21 = '┗';
pub const THICK_BOTTOM_RIGHT: u21 = '┛';
pub const THICK_LEFT: u21 = '┃';
pub const THICK_RIGHT: u21 = '┃';
pub const THICK_TOP: u21 = '━';
pub const THICK_BOTTOM: u21 = '━';

pub const THICK: Set = .{
    .top_left = THICK_TOP_LEFT,
    .top_right = THICK_TOP_RIGHT,
    .bottom_left = THICK_BOTTOM_LEFT,
    .bottom_right = THICK_BOTTOM_RIGHT,
    .left = THICK_LEFT,
    .right = THICK_RIGHT,
    .top = THICK_TOP,
    .bottom = THICK_BOTTOM,
};

pub const DOUBLE_TOP_LEFT: u21 = '╔';
pub const DOUBLE_TOP_RIGHT: u21 = '╗';
pub const DOUBLE_BOTTOM_LEFT: u21 = '╚';
pub const DOUBLE_BOTTOM_RIGHT: u21 = '╝';
pub const DOUBLE_LEFT: u21 = '║';
pub const DOUBLE_RIGHT: u21 = '║';
pub const DOUBLE_TOP: u21 = '═';
pub const DOUBLE_BOTTOM: u21 = '═';

pub const DOUBLE: Set = .{
    .top_left = DOUBLE_TOP_LEFT,
    .top_right = DOUBLE_TOP_RIGHT,
    .bottom_left = DOUBLE_BOTTOM_LEFT,
    .bottom_right = DOUBLE_BOTTOM_RIGHT,
    .left = DOUBLE_LEFT,
    .right = DOUBLE_RIGHT,
    .top = DOUBLE_TOP,
    .bottom = DOUBLE_BOTTOM,
};

pub const QUADRANT_INSIDE_TOP_LEFT: u21 = '▗';
pub const QUADRANT_INSIDE_TOP_RIGHT: u21 = '▖';
pub const QUADRANT_INSIDE_BOTTOM_LEFT: u21 = '▝';
pub const QUADRANT_INSIDE_BOTTOM_RIGHT: u21 = '▘';
pub const QUADRANT_INSIDE_LEFT: u21 = '▐';
pub const QUADRANT_INSIDE_RIGHT: u21 = '▌';
pub const QUADRANT_INSIDE_TOP: u21 = '▄';
pub const QUADRANT_INSIDE_BOTTOM: u21 = '▀';

pub const QUADRANT_INSIDE: Set = .{
    .top_left = QUADRANT_INSIDE_TOP_LEFT,
    .top_right = QUADRANT_INSIDE_TOP_RIGHT,
    .bottom_left = QUADRANT_INSIDE_BOTTOM_LEFT,
    .bottom_right = QUADRANT_INSIDE_BOTTOM_RIGHT,
    .left = QUADRANT_INSIDE_LEFT,
    .right = QUADRANT_INSIDE_RIGHT,
    .top = QUADRANT_INSIDE_TOP,
    .bottom = QUADRANT_INSIDE_BOTTOM,
};

pub const QUADRANT_OUTSIDE_TOP_LEFT: u21 = '▛';
pub const QUADRANT_OUTSIDE_TOP_RIGHT: u21 = '▜';
pub const QUADRANT_OUTSIDE_BOTTOM_LEFT: u21 = '▙';
pub const QUADRANT_OUTSIDE_BOTTOM_RIGHT: u21 = '▟';
pub const QUADRANT_OUTSIDE_LEFT: u21 = '▌';
pub const QUADRANT_OUTSIDE_RIGHT: u21 = '▐';
pub const QUADRANT_OUTSIDE_TOP: u21 = '▀';
pub const QUADRANT_OUTSIDE_BOTTOM: u21 = '▄';

pub const QUADRANT_OUTSIDE: Set = .{
    .top_left = QUADRANT_OUTSIDE_TOP_LEFT,
    .top_right = QUADRANT_OUTSIDE_TOP_RIGHT,
    .bottom_left = QUADRANT_OUTSIDE_BOTTOM_LEFT,
    .bottom_right = QUADRANT_OUTSIDE_BOTTOM_RIGHT,
    .left = QUADRANT_OUTSIDE_LEFT,
    .right = QUADRANT_OUTSIDE_RIGHT,
    .top = QUADRANT_OUTSIDE_TOP,
    .bottom = QUADRANT_OUTSIDE_BOTTOM,
};
