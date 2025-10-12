#!/usr/bin/env python3
"""Generate placeholder app icon PNGs in the asset catalog.

The script reads the existing Contents.json so that it only writes the filenames
referenced by the catalog. Each image receives a simple two-tone gradient so the
icons are visually distinct while remaining obviously placeholder artwork.
"""
from __future__ import annotations

import json
import sys
import zlib
from pathlib import Path
from typing import Iterable, Tuple

Color = Tuple[int, int, int, int]

# Palette of pleasant colors inspired by watery tones.
PALETTE: Tuple[Color, ...] = (
    (29, 161, 242, 255),   # blue
    (3, 218, 197, 255),    # teal
    (0, 184, 169, 255),    # turquoise
    (0, 132, 132, 255),    # deep teal
    (10, 132, 255, 255),   # vivid blue
    (64, 181, 173, 255),   # muted teal
)


def parse_size_token(size_token: str, scale_token: str) -> int:
    """Return the pixel dimension for the given size/scale tokens."""
    base = float(size_token.split("x")[0])
    scale = float(scale_token.replace("x", ""))
    pixels = int(round(base * scale))
    if pixels <= 0:
        raise ValueError(f"Derived non-positive pixel dimension for {size_token} @{scale_token}")
    return pixels


def gradient_rows(size: int, start: Color, end: Color) -> Iterable[bytes]:
    """Yield PNG rows with a vertical gradient between the two colors."""
    for y in range(size):
        t = y / max(size - 1, 1)
        r = int(start[0] + (end[0] - start[0]) * t)
        g = int(start[1] + (end[1] - start[1]) * t)
        b = int(start[2] + (end[2] - start[2]) * t)
        a = int(start[3] + (end[3] - start[3]) * t)
        row = bytes((r, g, b, a)) * size
        yield b"\x00" + row  # Filter type 0 for each scanline.


def write_png(path: Path, size: int, color_index: int) -> None:
    """Write a square RGBA PNG using the provided palette index."""
    start = PALETTE[color_index % len(PALETTE)]
    end = PALETTE[(color_index + len(PALETTE)//2) % len(PALETTE)]
    rows = b"".join(gradient_rows(size, start, end))
    compressed = zlib.compress(rows)

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            len(payload).to_bytes(4, "big")
            + tag
            + payload
            + zlib.crc32(tag + payload).to_bytes(4, "big")
        )

    header = chunk(
        b"IHDR",
        size.to_bytes(4, "big")
        + size.to_bytes(4, "big")
        + bytes((8, 6, 0, 0, 0)),  # 8-bit depth, RGBA
    )
    data = chunk(b"IDAT", compressed)
    end = chunk(b"IEND", b"")
    png_bytes = b"\x89PNG\r\n\x1a\n" + header + data + end
    path.write_bytes(png_bytes)


def generate_icons(app_icon_dir: Path) -> None:
    contents_path = app_icon_dir / "Contents.json"
    try:
        contents = json.loads(contents_path.read_text())
    except FileNotFoundError as exc:
        raise SystemExit(f"Could not find Contents.json at {contents_path}") from exc

    images = contents.get("images", [])
    if not images:
        raise SystemExit("App icon catalog does not define any images to generate.")

    for index, image in enumerate(images):
        filename = image.get("filename")
        if not filename:
            # Some slots (like watch marketing) may be left empty intentionally.
            continue
        size_token = image.get("size")
        scale_token = image.get("scale")
        if not size_token or not scale_token:
            raise SystemExit(f"Missing size or scale in {image}")
        size = parse_size_token(size_token, scale_token)
        output_path = app_icon_dir / filename
        output_path.parent.mkdir(parents=True, exist_ok=True)
        write_png(output_path, size, index)


def main(argv: Iterable[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {Path(argv[0]).name} <AppIcon.appiconset path>")
        return 1
    app_icon_dir = Path(argv[1]).expanduser().resolve()
    generate_icons(app_icon_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
