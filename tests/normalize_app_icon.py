"""Convert the checked-in indexed PNG AppIcon into true-color RGB in the CI checkout.
Uses only Python's standard library; preserves every palette RGB pixel exactly.
"""
from pathlib import Path
import struct
import zlib
import sys

SIGNATURE = b"\x89PNG\r\n\x1a\n"


def make_chunk(name, data):
    return (struct.pack(">I", len(data)) + name + data +
            struct.pack(">I", zlib.crc32(name + data) & 0xffffffff))


def paeth(a, b, c):
    p = a + b - c
    da, db, dc = abs(p-a), abs(p-b), abs(p-c)
    return a if da <= db and da <= dc else b if db <= dc else c


def normalize(path):
    data = path.read_bytes()
    if not data.startswith(SIGNATURE):
        raise ValueError("App icon is not PNG")
    parts = []
    position = 8
    while position < len(data):
        size = struct.unpack_from(">I", data, position)[0]
        name = data[position+4:position+8]
        payload = data[position+8:position+8+size]
        crc = struct.unpack_from(">I", data, position+8+size)[0]
        if (zlib.crc32(name+payload) & 0xffffffff) != crc:
            raise ValueError("Invalid PNG CRC")
        parts.append((name, payload))
        position += size+12
        if name == b"IEND":
            break

    header = next(p for t,p in parts if t == b"IHDR")
    width, height, depth, kind, compression, filt, interlace = struct.unpack(">IIBBBBB", header)
    if (width, height, depth, compression, filt, interlace) != (1024,1024,8,0,0,0):
        raise ValueError("Expected 1024x1024 non-interlaced 8-bit PNG")
    if any(t == b"tRNS" for t,_ in parts):
        raise ValueError("Icon contains transparency; don't silently flatten it")
    if kind == 2:
        print("App icon is RGB PNG (no conversion needed)")
        return
    if kind != 3:
        raise ValueError(f"App icon must be indexed (3) or RGB (2); received {kind}")
    palette_data = next(p for t,p in parts if t == b"PLTE")
    palette = [palette_data[i:i+3] for i in range(0,len(palette_data),3)]
    raw = zlib.decompress(b"".join(p for t,p in parts if t == b"IDAT"))
    if len(raw) != height*(width+1):
        raise ValueError("Unsupported palette bit depth or IDAT")
    last = bytearray(width)
    rendered = []
    cursor = 0
    for row_no in range(height):
        filter_code = raw[cursor]
        scan = raw[cursor+1:cursor+width]
        cursor += width+1
        if filter_code not in (0,1,2,3,4):
            raise ValueError("Unsupported PNG row filter")
        current = bytearray(width)
        for i, raw_value in enumerate(scan):
            left = current[i-1] if i else 0
            above = last[i]
            corner = last[i-1] if i else 0
            if filter_code == 0: predictor = 0
            elif filter_code == 1: predictor = left
            elif filter_code == 2: predictor = above
            elif filter_code == 3: predictor = (left+above)//2
            else: predictor = paeth(left, above, corner)
            current[i] = (raw_value+predictor) & 255
        rendered.append(b"\x00" + b"".join(palette[x] for x in current))
        last = current

    new_header = struct.pack(">IIBBBBB",width,height,8,2,0,0,0)
    new_data = (SIGNATURE + make_chunk(b"IHDR",new_header) +
                make_chunk(b"IDAT",zlib.compress(b"".join(rendered),9)) +
                make_chunk(b"IEND",b""))
    assert new_data[25] == 2
    tmp = path.with_name(path.name+".tmp")
    tmp.write_bytes(new_data)
    tmp.replace(path)
    print(f"Converted indexed PNG to RGB PNG: {len(data)} -> {len(new_data)} bytes (visual pixels unchanged)")


if __name__ == "__main__":
    normalize(Path(sys.argv[1]))
