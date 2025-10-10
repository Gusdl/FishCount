#!/usr/bin/env python3
"""Generate fish-themed AppIcon PNGs without external dependencies."""

import math
import os
import struct
import zlib

OUTPUT_DIR = os.path.join(
    os.path.dirname(__file__),
    "..",
    "Fischbestand",
    "Resources",
    "Assets.xcassets",
    "AppIcon.appiconset",
)

BASE_SIZE = 1024

BACKGROUND = (13, 58, 102)
BODY = (67, 166, 238)
FIN = (42, 126, 194)
BELLY = (207, 238, 252)
EYE_WHITE = (250, 252, 255)
EYE_PUPIL = (35, 64, 92)
BUBBLE = (173, 214, 255)


def clamp(value, lo=0.0, hi=1.0):
    return max(lo, min(hi, value))


def lerp(color_a, color_b, factor):
    return tuple(
        int(round(a + (b - a) * factor))
        for a, b in zip(color_a, color_b)
    )


def write_png_rgb(path, pixels, width, height):
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        start = y * stride
        raw.extend(pixels[start : start + stride])

    compressor = zlib.compressobj()
    compressed = compressor.compress(bytes(raw)) + compressor.flush()

    def chunk(chunk_type, data):
        return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)

    png_bytes = bytearray(b"\x89PNG\r\n\x1a\n")
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png_bytes.extend(chunk(b"IHDR", ihdr))
    png_bytes.extend(chunk(b"IDAT", compressed))
    png_bytes.extend(chunk(b"IEND", b""))

    data = bytes(png_bytes)
    if os.path.exists(path):
        with open(path, "rb") as existing:
            if existing.read() == data:
                return False

    with open(path, "wb") as fh:
        fh.write(data)
    return True


def generate_base(size):
    pixels = bytearray(size * size * 3)
    half = size / 2.0
    for y in range(size):
        for x in range(size):
            nx = (x - half) / half
            ny = (y - half) / half

            color = BACKGROUND

            # Gentle water gradient
            depth = clamp((ny + 1) / 2)
            color = lerp(color, (9, 33, 63), depth * 0.35)

            # Body ellipse
            body_center = (-0.1, 0.0)
            body_radius_x = 0.75
            body_radius_y = 0.52
            dx = nx - body_center[0]
            dy = ny - body_center[1]
            body_value = (dx ** 2) / (body_radius_x ** 2) + (dy ** 2) / (body_radius_y ** 2)
            if body_value <= 1.0:
                shading = clamp(0.5 + (-dx * 0.3) + (dy * 0.2))
                color = lerp(BODY, BELLY, shading)

            # Tail triangle
            tail_left = -0.85
            tail_width = 0.35
            tail_height = 0.6
            if nx < tail_left + tail_width:
                tail_factor = (nx - tail_left) / tail_width
                if abs(ny) <= (1 - tail_factor) * (tail_height / 2):
                    color = lerp(FIN, BODY, tail_factor)

            # Dorsal fin
            fin_peak = (-0.15, -0.55)
            fin_base_left = (-0.55, -0.15)
            fin_base_right = (0.2, -0.1)
            if ny < -0.1 and nx >= fin_base_left[0] and nx <= fin_base_right[0]:
                # barycentric coordinates for triangle shading
                denom = ((fin_base_right[1] - fin_peak[1]) * (fin_base_left[0] - fin_peak[0]) +
                         (fin_peak[0] - fin_base_right[0]) * (fin_base_left[1] - fin_peak[1]))
                if denom != 0:
                    a = ((fin_base_right[1] - fin_peak[1]) * (nx - fin_peak[0]) + (fin_peak[0] - fin_base_right[0]) * (ny - fin_peak[1])) / denom
                    b = ((fin_peak[1] - fin_base_left[1]) * (nx - fin_peak[0]) + (fin_base_left[0] - fin_peak[0]) * (ny - fin_peak[1])) / denom
                    c = 1 - a - b
                    if 0 <= a <= 1 and 0 <= b <= 1 and 0 <= c <= 1:
                        color = lerp(FIN, BODY, clamp(0.3 + 0.7 * c))

            # Pectoral fin (circle segment)
            fin_center = (0.1, 0.25)
            fin_radius = 0.22
            fx = nx - fin_center[0]
            fy = ny - fin_center[1]
            if fx * fx + fy * fy <= fin_radius * fin_radius and nx > -0.15:
                blend = clamp((fin_radius - math.sqrt(fx * fx + fy * fy)) / fin_radius)
                color = lerp(FIN, BODY, blend * 0.6)

            # Eye white
            eye_center = (0.32, -0.05)
            eye_radius = 0.12
            ex = nx - eye_center[0]
            ey = ny - eye_center[1]
            eye_dist = math.sqrt(ex * ex + ey * ey)
            if eye_dist <= eye_radius:
                color = EYE_WHITE
                # pupil
                pupil_radius = eye_radius * 0.45
                if eye_dist <= pupil_radius:
                    color = EYE_PUPIL

            # Highlight spot
            highlight_center = (0.05, -0.18)
            hx = nx - highlight_center[0]
            hy = ny - highlight_center[1]
            if hx * hx + hy * hy <= 0.1 ** 2:
                color = lerp(color, (255, 255, 255), 0.3)

            # Subtle bubbles near mouth
            bubble_center = (0.65, -0.35)
            bx = nx - bubble_center[0]
            by = ny - bubble_center[1]
            if bx * bx + by * by <= 0.03 ** 2:
                color = lerp(BUBBLE, BACKGROUND, 0.3)
            bubble_center2 = (0.75, -0.15)
            bx = nx - bubble_center2[0]
            by = ny - bubble_center2[1]
            if bx * bx + by * by <= 0.025 ** 2:
                color = lerp(BUBBLE, BACKGROUND, 0.15)

            idx = (y * size + x) * 3
            pixels[idx:idx+3] = bytes(color)
    return pixels


def resize_nearest(pixels, src_size, dst_size):
    src_w = src_h = src_size
    dst_w = dst_h = dst_size
    src_stride = src_w * 3
    dst = bytearray(dst_w * dst_h * 3)
    for y in range(dst_h):
        src_y = int(y * src_h / dst_h)
        for x in range(dst_w):
            src_x = int(x * src_w / dst_w)
            src_idx = src_y * src_stride + src_x * 3
            dst_idx = (y * dst_w + x) * 3
            dst[dst_idx:dst_idx+3] = pixels[src_idx:src_idx+3]
    return dst


def ensure_output_dir():
    os.makedirs(OUTPUT_DIR, exist_ok=True)


def main():
    ensure_output_dir()
    base_pixels = generate_base(BASE_SIZE)

    targets = {
        20: "Icon-20.png",
        29: "Icon-29.png",
        40: "Icon-40.png",
        58: "Icon-58.png",
        60: "Icon-60.png",
        76: "Icon-76.png",
        80: "Icon-80.png",
        87: "Icon-87.png",
        120: "Icon-120.png",
        152: "Icon-152.png",
        167: "Icon-167.png",
        180: "Icon-180.png",
        1024: "Icon-1024.png",
    }

    for size, filename in targets.items():
        if size == BASE_SIZE:
            pixels = base_pixels
        else:
            pixels = resize_nearest(base_pixels, BASE_SIZE, size)
        written = write_png_rgb(os.path.join(OUTPUT_DIR, filename), pixels, size, size)
        status = "Wrote" if written else "Up-to-date"
        print(f"{status} {filename} ({size}x{size})")


if __name__ == "__main__":
    main()
