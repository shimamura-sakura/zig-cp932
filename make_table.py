#!/bin/env python3

pairs = []

with open('CP932.TXT', 'r') as file:
    step_1 = map(lambda s: s.strip(), file)
    step_2 = filter(lambda s: not s.startswith('#'), step_1)
    step_3 = map(lambda s: s.split('\t'), step_2)
    for jis, uni, _ in step_3:
        jis = jis.strip()
        uni = uni.strip()
        if len(uni) == 0:
            continue
        pairs.append((int(jis, 16), int(uni, 16)))

with open('cp932-table.zig', 'w') as file:
    pairs.sort(key=lambda v: v[0])
    print('pub const cp932_unicode = [_][2]u16{', file=file)
    for jis, uni in pairs:
        print('    .{ 0x%x, 0x%x },' % (jis, uni), file=file)
    print('};', file=file)
    pairs.sort(key=lambda v: v[1])
    print('pub const unicode_cp932 = [_][2]u16{', file=file)
    for jis, uni in pairs:
        print('    .{ 0x%x, 0x%x },' % (uni, jis), file=file)
    print('};', file=file)
