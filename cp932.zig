const tables = @import("cp932-table.zig");

fn binLookup(table: []const [2]u16, x: u16) ?u16 {
    var l: usize = 0;
    var r = table.len;
    while (l < r) {
        const m = (l + r) / 2;
        const p = table[m];
        if (x < p[0])
            r = m
        else if (x > p[0])
            l = m + 1
        else
            return p[1];
    }
    return null;
}

fn lookup_cp932(x: u16) ?u16 {
    return binLookup(&tables.cp932_unicode, x);
}

fn lookup_unicode(x: u16) ?u16 {
    return binLookup(&tables.unicode_cp932, x);
}

pub const Decoder = struct {
    high: ?u8 = null,
    pub const Error = error{InvalidHigh};
    pub fn input(self: *@This(), byte: u8) Error!?u16 {
        if (self.high) |h| {
            if (lookup_cp932((@intCast(u16, h) << 8) + byte)) |ok| {
                self.high = null;
                return ok;
            }
            return Error.InvalidHigh;
        }
        if (lookup_cp932(byte)) |ok|
            return ok;
        self.high = byte;
        return null;
    }
};

pub const OneTwo = union((enum { one, two })) {
    one: u8,
    two: [2]u8,
};

pub fn encodeCodepoint(cp: u16) ?OneTwo {
    return switch (lookup_unicode(cp) orelse return null) {
        0x00...0xFF => |x| OneTwo{ .one = @truncate(u8, x) },
        else => |x| OneTwo{ .two = [2]u8{
            @truncate(u8, x >> 8),
            @truncate(u8, x >> 0),
        } },
    };
}

pub const FmtCP932Slice = struct {
    slice: []const u8,
    pub fn format(self: @This(), _: anytype, _: anytype, writer: anytype) !void {
        var decoder = Decoder{};
        for (self.slice) |b| {
            if (decoder.input(b) catch |e| return try writer.print("{}", .{e})) |u|
                try writer.print("{u}", .{u});
        }
    }
};

pub fn fmtCP932Slice(slice: []const u8) FmtCP932Slice {
    return .{ .slice = slice };
}

test "decode" {
    const std = @import("std");
    const INPUT = [_]u8{
        130, 187, 130, 204, 137, 212, 130, 209, 130, 231, 130,
        201, 130, 173, 130, 191, 130, 195, 130, 175, 130, 240,
    };
    var decoder = Decoder{};
    for (INPUT) |b| {
        if (try decoder.input(b)) |ok| {
            try std.testing.expect(std.unicode.utf8ValidCodepoint(ok));
            std.debug.print("{}", .{std.unicode.fmtUtf16le(&[1]u16{ok})});
        }
    }
    std.debug.print("\n", .{});
}

test "encode" {
    const std = @import("std");
    const ANSWER = [_]u8{
        130, 187, 130, 204, 137, 212, 130, 209, 130, 231, 130,
        201, 130, 173, 130, 191, 130, 195, 130, 175, 130, 240,
    };
    const view = try std.unicode.Utf8View.init("その花びらにくちづけを");
    var i: usize = 0;
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |cp| {
        switch (encodeCodepoint(@intCast(u16, cp)).?) {
            .one => |x| {
                try std.testing.expect(ANSWER[i] == x);
                i += 1;
            },
            .two => |x| {
                try std.testing.expect(std.mem.eql(u8, ANSWER[i .. i + 2], &x));
                i += 2;
            },
        }
    }
}
