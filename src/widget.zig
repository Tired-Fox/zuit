/// Block Widget
///
/// A container that wraps a specific area. This container
/// is mainly used for displaying borders and to apply padding.
///
/// Use the `inner` method to get the wrapped area after the borders
/// and padding are applied.
pub const border = @import("./widget/border.zig");
pub const text = @import("./widget/text.zig");
pub const gauge = @import("./widget/text.zig");
pub const layout = @import("./widget/layout.zig");
pub const list = @import("./widget/list.zig");
pub const scroll = @import("./widget/scroll.zig");

pub const Buffer = @import("./root.zig").Buffer;
pub const Rect = @import("./root.zig").Rect;

pub const Block = @import("./widget/block.zig");

pub const Borders = @import("./widget/border.zig").Borders;
pub const BorderType = @import("./widget/border.zig").BorderType;

pub const Layout = @import("./widget/layout.zig").Layout;
pub const Constraint = @import("./widget/layout.zig").Constraint;

pub const Title = @import("./widget/text.zig").Title;
pub const Span = @import("./widget/text.zig").Span;
pub const Line = @import("./widget/text.zig").Line;
pub const Paragraph = @import("./widget/text.zig").Paragraph;

pub const Gauge = @import("./widget/gauge.zig").Gauge;
pub const LineGauge = @import("./widget/gauge.zig").LineGauge;

pub const ScrollBar = @import("./widget/scroll.zig").ScrollBar;

pub const List = @import("./widget/list.zig").List;

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
};

/// Widget that when rendered will clear the area it is rendered to.
pub const Clear = struct {
    pub fn render(self: *const @This(), buffer: *Buffer, rect: Rect) !void {
        _ = self;
        buffer.fill(rect, ' ', null);
    }
}{};

pub const Align = enum {
    start,
    center,
    end,
};
