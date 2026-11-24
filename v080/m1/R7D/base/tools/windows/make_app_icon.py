#!/usr/bin/env python3
"""Builds the Windows program icon assets/icons/app_icon.ico from the Steam icon.

Source: marketing/steam/icon.ico (tools/steam/compose.py) – seven frames 16, 24, 32, 48, 64, 128 and 256 px,
the small ones (16/24/32) drawn as a simplified high-contrast variant. The frames are taken over pixel for
pixel and written in the classic Windows layout:
  * 16 … 128 px as 32-bit BMP (BGRA with alpha + 1-bit AND mask), 256 px as PNG,
  * every directory entry with 1 colour plane and 32 bits per pixel.
Windows Explorer, the taskbar and DisplayServer.set_native_icon() (application/config/windows_native_icon)
read every frame; the Windows export (application/modify_resources) copies the frames into the .exe.

Usage (from the repository root, Python 3 with Pillow):
    python3 tools/windows/make_app_icon.py [source.ico] [target.ico]
"""
import io
import os
import struct
import sys

from PIL import Image

SIZES = (16, 24, 32, 48, 64, 128, 256)
PNG_MIN = 256  # frames from this size on are stored as PNG (Windows Vista and later), smaller ones as BMP


def bmp_frame(img: Image.Image) -> bytes:
    """32-bit icon bitmap: BITMAPINFOHEADER (double height), BGRA rows bottom-up, AND mask bottom-up."""
    w, h = img.size
    px = img.load()
    xor = bytearray()
    mask_stride = ((w + 31) // 32) * 4
    mask = bytearray()
    for y in range(h - 1, -1, -1):
        row_mask = bytearray(mask_stride)
        for x in range(w):
            r, g, b, a = px[x, y]
            xor += bytes((b, g, r, a))
            if a == 0:
                row_mask[x // 8] |= 0x80 >> (x % 8)
        mask += row_mask
    header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, len(xor) + len(mask), 0, 0, 0, 0)
    return header + bytes(xor) + bytes(mask)


def png_frame(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def build(src: str, dst: str) -> None:
    frames = []
    with Image.open(src) as ico:
        available = {s[0] for s in ico.ico.sizes()}
        missing = [s for s in SIZES if s not in available]
        if missing:
            raise SystemExit("%s: Größen fehlen: %s" % (src, missing))
        for s in SIZES:
            img = ico.ico.getimage((s, s)).convert("RGBA")
            if img.size != (s, s):
                raise SystemExit("%s: Bild %d px hat %s" % (src, s, img.size))
            frames.append((s, png_frame(img) if s >= PNG_MIN else bmp_frame(img)))
    out = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
    offset = 6 + 16 * len(frames)
    for s, data in frames:
        dim = s if s < 256 else 0
        out += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    for _, data in frames:
        out += data
    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    with open(dst, "wb") as f:
        f.write(out)
    print("%s: %d Bilder (%s px), %d Bytes" % (dst, len(frames), ", ".join(str(s) for s, _ in frames), len(out)))


def check(src: str, dst: str) -> None:
    """Every frame of the result must equal the source frame pixel for pixel."""
    with Image.open(src) as a, Image.open(dst) as b:
        for s in SIZES:
            fa = a.ico.getimage((s, s)).convert("RGBA")
            fb = b.ico.getimage((s, s)).convert("RGBA")
            if fa.tobytes() != fb.tobytes():
                raise SystemExit("%s: Bild %d px weicht von der Quelle ab" % (dst, s))
    print("geprüft: alle %d Bilder pixelgleich mit %s" % (len(SIZES), src))


if __name__ == "__main__":
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    source = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "marketing", "steam", "icon.ico")
    target = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, "assets", "icons", "app_icon.ico")
    build(source, target)
    check(source, target)
