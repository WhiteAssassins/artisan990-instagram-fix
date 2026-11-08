import struct, sys
src, dst, type_id, entry_idx, old, new = sys.argv[1], sys.argv[2], int(sys.argv[3],16), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
d = bytearray(open(src,'rb').read())
def hdr(o): return struct.unpack_from('<HHI', d, o)
t, hs, size = hdr(0); assert t == 0x0002
o = hs; hits = []
while o < len(d):
    ct, chs, csz = hdr(o)
    if ct == 0x0200:  # package
        p = o + chs
        while p < o + csz:
            pt, phs, psz = hdr(p)
            if pt == 0x0201:  # type chunk
                tid, flags = d[p+8], d[p+9]
                count, estart = struct.unpack_from('<II', d, p+12)
                if tid == type_id:
                    if flags & 0x01:  # sparse
                        for i in range(count):
                            idx, off4 = struct.unpack_from('<HH', d, p+phs+4*i)
                            if idx == entry_idx: eoff = off4*4; break
                        else: eoff = None
                    else:
                        eoff = struct.unpack_from('<I', d, p+phs+4*entry_idx)[0] if entry_idx < count else 0xFFFFFFFF
                        if eoff == 0xFFFFFFFF: eoff = None
                    if eoff is not None:
                        e = p + estart + eoff
                        esize, eflags = struct.unpack_from('<HH', d, e)
                        if eflags & 0x08:  # compact entry: data in key field
                            vtype = eflags >> 8; val_off = e+4
                        else:
                            assert not (eflags & 0x01), "complex entry"
                            vsize, res0, vtype = struct.unpack_from('<HBB', d, e+esize)
                            val_off = e+esize+4
                        val = struct.unpack_from('<I', d, val_off)[0]
                        hits.append((val_off, vtype, val))
            p += psz
    o += csz
print("hits:", [(hex(a), hex(t), v) for a,t,v in hits])
assert len(hits) == 1, "expected exactly one config for entry"
a, vt, v = hits[0]
assert vt == 0x10 and v == old, f"unexpected value type={vt:#x} val={v}"
struct.pack_into('<I', d, a, new)
open(dst,'wb').write(d)
diff = [i for i in range(len(d)) if d[i] != open(src,'rb').read()[i]]
print("bytes changed:", len(diff), [hex(i) for i in diff])
