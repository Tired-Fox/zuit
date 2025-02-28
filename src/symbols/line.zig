pub const Set = struct {
    vertical: u21 = ' ',
    horizontal: u21 = ' ',
    top_right: u21 = ' ',
    top_left: u21 = ' ',
    bottom_right: u21 = ' ',
    bottom_left: u21 = ' ',
    vertical_left: u21 = ' ',
    vertical_right: u21 = ' ',
    horizontal_down: u21 = ' ',
    horizontal_up: u21 = ' ',
    cross: u21 = ' ',
};

pub const THICK_VERTICAL: u21 = '┃';
pub const THICK_HORIZONTAL: u21 = '━';
pub const THICK_TOP_RIGHT: u21 = '┓';
pub const THICK_TOP_LEFT: u21 = '┏';
pub const THICK_BOTTOM_RIGHT: u21 = '┛';
pub const THICK_BOTTOM_LEFT: u21 = '┗';
pub const THICK_VERTICAL_LEFT: u21 = '┫';
pub const THICK_VERTICAL_RIGHT: u21 = '┣';
pub const THICK_HORIZONTAL_DOWN: u21 = '┳';
pub const THICK_HORIZONTAL_UP: u21 = '┻';
pub const THICK_CROSS: u21 = '╋';

pub const THICK: Set = .{
    .vertical = THICK_VERTICAL,
    .horizontal = THICK_HORIZONTAL,
    .top_right = THICK_TOP_RIGHT,
    .top_left = THICK_TOP_LEFT,
    .bottom_right = THICK_BOTTOM_RIGHT,
    .bottom_left = THICK_BOTTOM_LEFT,
    .vertical_left = THICK_VERTICAL_LEFT,
    .vertical_right = THICK_VERTICAL_RIGHT,
    .horizontal_down = THICK_HORIZONTAL_DOWN,
    .horizontal_up = THICK_HORIZONTAL_UP,
    .cross = THICK_CROSS,
};

pub const DOUBLE_VERTICAL: u21 = '║';
pub const DOUBLE_HORIZONTAL: u21 = '═';
pub const DOUBLE_TOP_RIGHT: u21 = '╗';
pub const DOUBLE_TOP_LEFT: u21 = '╔';
pub const DOUBLE_BOTTOM_RIGHT: u21 = '╝';
pub const DOUBLE_BOTTOM_LEFT: u21 = '╚';
pub const DOUBLE_VERTICAL_LEFT: u21 = '╣';
pub const DOUBLE_VERTICAL_RIGHT: u21 = '╠';
pub const DOUBLE_HORIZONTAL_DOWN: u21 = '╦';
pub const DOUBLE_HORIZONTAL_UP: u21 = '╩';
pub const DOUBLE_CROSS: u21 = '╬';

pub const DOUBLE: Set = .{
    .vertical = DOUBLE_VERTICAL,
    .horizontal = DOUBLE_HORIZONTAL,
    .top_right = DOUBLE_TOP_RIGHT,
    .top_left = DOUBLE_TOP_LEFT,
    .bottom_right = DOUBLE_BOTTOM_RIGHT,
    .bottom_left = DOUBLE_BOTTOM_LEFT,
    .vertical_left = DOUBLE_VERTICAL_LEFT,
    .vertical_right = DOUBLE_VERTICAL_RIGHT,
    .horizontal_down = DOUBLE_HORIZONTAL_DOWN,
    .horizontal_up = DOUBLE_HORIZONTAL_UP,
    .cross = DOUBLE_CROSS,
};

pub const VERTICAL: u21 = '│';
pub const HORIZONTAL: u21 = '─';
pub const TOP_RIGHT: u21 = '┐';
pub const TOP_LEFT: u21 = '┌';
pub const BOTTOM_RIGHT: u21 = '└';
pub const BOTTOM_LEFT: u21 = '┘';
pub const VERTICAL_LEFT: u21 = '┤';
pub const VERTICAL_RIGHT: u21 = '├';
pub const HORIZONTAL_DOWN: u21 = '┬';
pub const HORIZONTAL_UP: u21 = '┴';
pub const CROSS: u21 = '┼';

pub const NORMAL: Set = .{
    .vertical = VERTICAL,
    .horizontal = HORIZONTAL,
    .top_right = TOP_RIGHT,
    .top_left = TOP_LEFT,
    .bottom_right = BOTTOM_RIGHT,
    .bottom_left = BOTTOM_LEFT,
    .vertical_left = VERTICAL_LEFT,
    .vertical_right = VERTICAL_RIGHT,
    .horizontal_down = HORIZONTAL_DOWN,
    .horizontal_up = HORIZONTAL_UP,
    .cross = CROSS,
};

pub const ROUNDED_TOP_RIGHT: u21 = '╮';
pub const ROUNDED_TOP_LEFT: u21 = '╭';
pub const ROUNDED_BOTTOM_RIGHT: u21 = '╯';
pub const ROUNDED_BOTTOM_LEFT: u21 = '╰';

pub const ROUNDED: Set = .{
    .vertical = VERTICAL,
    .horizontal = HORIZONTAL,
    .top_right = ROUNDED_TOP_RIGHT,
    .top_left = ROUNDED_TOP_LEFT,
    .bottom_right = ROUNDED_BOTTOM_RIGHT,
    .bottom_left = ROUNDED_BOTTOM_LEFT,
    .vertical_left = VERTICAL_LEFT,
    .vertical_right = VERTICAL_RIGHT,
    .horizontal_down = HORIZONTAL_DOWN,
    .horizontal_up = HORIZONTAL_UP,
    .cross = CROSS,
};
