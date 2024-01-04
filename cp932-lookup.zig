pub const Entry = struct { u8, u8, u16 };
pub const Encode = union(enum) { single: u8, double: [2]u8 };
pub const DecError = error{ InvalidFirst, InvalidSecond, NeverInCP932, NoSpaceLeft };
pub const EncError = error{ InvalidCodepoint, NoSpaceLeft };
fn isEntZero(entry: Entry) bool {
    return entry[0] == 0 and entry[1] == 0 and entry[2] == 0;
}
pub fn Decoder(comptime entries: anytype, comptime litvals: anytype) type {
    return struct {
        const ZENTRY = .{ 0, 0, 0 };
        entry: Entry = ZENTRY,
        pub fn input(self: *@This(), byte: u8) DecError!?u16 {
            if (byte >= 253) {
                self.entry = ZENTRY;
                return DecError.NeverInCP932;
            }
            if (isEntZero(self.entry)) {
                const new_ent = entries[byte];
                if (isEntZero(new_ent)) return DecError.InvalidFirst;
                if (new_ent[0] == 0 and new_ent[1] == 0) return new_ent[2];
                self.entry = new_ent;
                return null;
            } else {
                defer self.entry = ZENTRY;
                const min = self.entry[0];
                const max = self.entry[1];
                const off = self.entry[2];
                if (byte < min or max < byte) return DecError.InvalidSecond;
                const lit = litvals[off + byte - min];
                if (lit == 0) return DecError.InvalidSecond;
                return lit;
            }
        }
        pub fn calcU16Count(slice: []const u8) DecError!usize {
            var count: usize = 0;
            var decoder = @This(){};
            for (slice) |b| if (try decoder.input(b)) |_| {
                count += 1;
            };
            return count;
        }
        pub fn decodeSlice(slice: []const u8, buffer: []u16) DecError![]const u16 {
            var index: usize = 0;
            var decoder = @This(){};
            for (slice) |b| if (try decoder.input(b)) |u| {
                if (index + 1 > buffer.len) return error.NoSpaceLeft;
                buffer[index] = u;
                index += 1;
            };
            return buffer[0..index];
        }
    };
}
pub fn Encoder(comptime entries: anytype, comptime litvals: anytype) type {
    return struct {
        pub fn encode(codepoint: u16) EncError!Encode {
            const hi = @as(u8, @intCast(codepoint >> 0x8));
            const lo = @as(u8, @intCast(codepoint & 0xFF));
            const ent = entries[hi];
            const min = ent[0];
            const max = ent[1];
            const off = ent[2];
            if (lo < min or max < lo) return EncError.InvalidCodepoint;
            const lit = litvals[off + lo - min];
            if (lit == 0) return EncError.InvalidCodepoint;
            return if (lit <= 0xFF) .{ .single = @as(u8, @intCast(lit)) } else .{ .double = .{
                @as(u8, @intCast(lit >> 0x8)),
                @as(u8, @intCast(lit & 0xFF)),
            } };
        }
        pub fn calcU8Count(slice: []const u16) EncError!usize {
            var count: usize = 0;
            for (slice) |u| switch (try encode(u)) {
                .single => count += 1,
                .double => count += 2,
            };
            return count;
        }
        pub fn encodeSlice(slice: []const u16, buffer: []u8) EncError![]const u8 {
            var index: usize = 0;
            for (slice) |u| switch (try encode(u)) {
                .single => |b| {
                    if (index + 1 > buffer.len) return error.NoSpaceLeft;
                    buffer[index] = b;
                    index += 1;
                },
                .double => |bs| {
                    if (index + 2 > buffer.len) return error.NoSpaceLeft;
                    buffer[index + 0] = bs[0];
                    buffer[index + 1] = bs[1];
                    index += 2;
                },
            };
            return buffer[0..index];
        }
    };
}
