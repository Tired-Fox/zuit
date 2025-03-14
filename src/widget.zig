pub const border = @import("./widget/border.zig");
pub const text = @import("./widget/text.zig");
pub const gauge = @import("./widget/text.zig");
pub const layout = @import("./widget/layout.zig");
pub const scroll = @import("./widget/scroll.zig");
pub const list = @import("./widget/list.zig");
pub const table = @import("./widget/table.zig");

pub const Buffer = @import("./root.zig").Buffer;
pub const Rect = @import("./root.zig").Rect;

/// Block Widget
///
/// A container that wraps a specific area. This container
/// is mainly used for displaying borders and titles, along with applying padding.
///
/// Use the `inner` method to get the wrapped area after the borders
/// and padding are applied.
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

pub const Table = @import("./widget/table.zig").Table;
pub const Row = @import("./widget/table.zig").Row;
pub const TableState = @import("./widget/table.zig").TableState;

/// Alignment to relative to a container
pub const Align = enum {
    start,
    center,
    end,
};
