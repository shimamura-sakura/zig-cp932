const std = @import("std");
const jis = @import("cp932-table.zig");

pub fn UStr(comptime T: type) type {
    return struct {
        u16s: T,
        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            for (self.u16s) |u| try writer.print("{u}", .{u});
        }
    };
}

pub fn ustr(u16s: anytype) UStr(@TypeOf(u16s)) {
    return .{ .u16s = u16s };
}

pub fn JStr(comptime T: type) type {
    return struct {
        bytes: T,
        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            var decoder = jis.decoder;
            for (self.bytes) |b| if (decoder.input(b) catch '?') |u| try writer.print("{u}", .{u});
        }
    };
}

pub fn jstr(bytes: anytype) JStr(@TypeOf(bytes)) {
    return .{ .bytes = bytes };
}
