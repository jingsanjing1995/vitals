#!/usr/bin/env python3
"""Generate the VITALS app icon and macOS .icns file.

The icon is drawn at 4x and downsampled for crisp antialiasing. No external
image assets are required.
"""

from __future__ import annotations

import math
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "Resources"
DOCS = ROOT / "docs"
ICNS_PATH = RESOURCES / "AppIcon.icns"
PNG_PATH = DOCS / "icon.png"

SCALE = 4
CANVAS = 1024


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_value.lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16),
        alpha,
    )


def lerp(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def multi_gradient(stops: list[tuple[float, tuple[int, int, int, int]]], t: float):
    for index in range(len(stops) - 1):
        start_t, start_color = stops[index]
        end_t, end_color = stops[index + 1]
        if start_t <= t <= end_t:
            local = (t - start_t) / max(1e-6, end_t - start_t)
            return lerp(start_color, end_color, local)
    return stops[-1][1]


def rounded_mask(size: int, box: tuple[int, int, int, int], radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def draw_icon() -> Image.Image:
    size = CANVAS * SCALE
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    margin = 76 * SCALE
    box = (margin, margin, size - margin, size - margin)
    mask = rounded_mask(size, box, radius=204 * SCALE)

    # Base vertical gradient.
    base = Image.new("RGBA", (size, size))
    pixels = base.load()
    top = rgba("#15233B")
    middle = rgba("#0C1424")
    bottom = rgba("#070A12")
    for y in range(size):
        t = y / max(1, size - 1)
        if t < 0.48:
            color = lerp(top, middle, t / 0.48)
        else:
            color = lerp(middle, bottom, (t - 0.48) / 0.52)
        for x in range(size):
            pixels[x, y] = color
    image.alpha_composite(Image.composite(base, Image.new("RGBA", (size, size)), mask))
    draw = ImageDraw.Draw(image)

    # Soft colored atmosphere.
    glow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow = ImageDraw.Draw(glow_layer)
    glow.ellipse(
        (
            -90 * SCALE,
            -120 * SCALE,
            640 * SCALE,
            610 * SCALE,
        ),
        fill=rgba("#46D8FF", 105),
    )
    glow.ellipse(
        (
            540 * SCALE,
            470 * SCALE,
            1230 * SCALE,
            1160 * SCALE,
        ),
        fill=rgba("#8666FF", 105),
    )
    glow.ellipse(
        (
            520 * SCALE,
            690 * SCALE,
            1080 * SCALE,
            1190 * SCALE,
        ),
        fill=rgba("#FF6FCB", 52),
    )
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(150 * SCALE))
    image.alpha_composite(Image.composite(glow_layer, Image.new("RGBA", (size, size)), mask))

    draw = ImageDraw.Draw(image)
    center = (size // 2, size // 2)
    ring_radius = 248 * SCALE
    ring_width = 43 * SCALE

    # Faint full track and tick ring.
    draw.arc(
        (
            center[0] - ring_radius,
            center[1] - ring_radius,
            center[0] + ring_radius,
            center[1] + ring_radius,
        ),
        start=0,
        end=360,
        fill=rgba("#2A3444", 255),
        width=ring_width,
    )

    tick_count = 60
    active_fraction = 0.69
    for index in range(tick_count):
        fraction = index / tick_count
        angle = fraction * math.tau - math.pi / 2
        major = index % 5 == 0
        inner = ring_radius + 47 * SCALE
        outer = inner + (15 if major else 9) * SCALE
        lit = fraction <= active_fraction
        color = rgba("#5DD4E8", 255) if lit else rgba("#3A485A", 255)
        width = 5 * SCALE if major else 3 * SCALE
        x1 = center[0] + math.cos(angle) * inner
        y1 = center[1] + math.sin(angle) * inner
        x2 = center[0] + math.cos(angle) * outer
        y2 = center[1] + math.sin(angle) * outer
        draw.line((x1, y1, x2, y2), fill=color, width=width)

    # Gradient gauge arc.
    stops = [
        (0.0, rgba("#6BE9FF")),
        (0.36, rgba("#5B8DFF")),
        (0.68, rgba("#A78BFA")),
        (1.0, rgba("#FF7AD9")),
    ]
    start_angle = -90.0
    sweep = 360.0 * active_fraction
    segments = 320
    for index in range(segments):
        t0 = index / segments
        t1 = (index + 1.3) / segments
        a0 = math.radians(start_angle + sweep * t0)
        a1 = math.radians(start_angle + sweep * t1)
        color = multi_gradient(stops, t0)
        p0 = (
            center[0] + math.cos(a0) * ring_radius,
            center[1] + math.sin(a0) * ring_radius,
        )
        p1 = (
            center[0] + math.cos(a1) * ring_radius,
            center[1] + math.sin(a1) * ring_radius,
        )
        draw.line((p0, p1), fill=color, width=ring_width)
        draw.ellipse(
            (
                p0[0] - ring_width / 2,
                p0[1] - ring_width / 2,
                p0[0] + ring_width / 2,
                p0[1] + ring_width / 2,
            ),
            fill=color,
        )

    # Glowing endpoint.
    end_angle = math.radians(start_angle + sweep)
    end_point = (
        center[0] + math.cos(end_angle) * ring_radius,
        center[1] + math.sin(end_angle) * ring_radius,
    )
    dot_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dot_draw = ImageDraw.Draw(dot_layer)
    dot_r = 13 * SCALE
    dot_draw.ellipse(
        (
            end_point[0] - dot_r,
            end_point[1] - dot_r,
            end_point[0] + dot_r,
            end_point[1] + dot_r,
        ),
        fill=rgba("#FFFFFF", 255),
    )
    dot_layer = dot_layer.filter(ImageFilter.GaussianBlur(4 * SCALE))
    image.alpha_composite(Image.composite(dot_layer, Image.new("RGBA", (size, size)), mask))
    draw = ImageDraw.Draw(image)

    # CPU chip silhouette.
    chip_size = 174 * SCALE
    chip_box = (
        center[0] - chip_size // 2,
        center[1] - chip_size // 2,
        center[0] + chip_size // 2,
        center[1] + chip_size // 2,
    )
    chip_fill = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    chip_draw = ImageDraw.Draw(chip_fill)
    chip_draw.rounded_rectangle(
        chip_box,
        radius=39 * SCALE,
        fill=rgba("#0A1425", 255),
        outline=rgba("#7FE8FF", 255),
        width=10 * SCALE,
    )
    chip_draw.rounded_rectangle(
        (
            chip_box[0] + 29 * SCALE,
            chip_box[1] + 29 * SCALE,
            chip_box[2] - 29 * SCALE,
            chip_box[3] - 29 * SCALE,
        ),
        radius=20 * SCALE,
        outline=rgba("#5876A8", 255),
        width=4 * SCALE,
    )
    image.alpha_composite(Image.composite(chip_fill, Image.new("RGBA", (size, size)), mask))
    draw = ImageDraw.Draw(image)

    # Chip pins.
    pin_length = 26 * SCALE
    pin_width = 11 * SCALE
    pin_offsets = [-48, 0, 48]
    for offset in pin_offsets:
        for direction in (-1, 1):
            px = center[0] + offset * SCALE
            py1 = center[1] + direction * (chip_size // 2)
            py2 = center[1] + direction * (chip_size // 2 + pin_length)
            draw.rounded_rectangle(
                (
                    min(px - pin_width / 2, px - pin_width / 2),
                    min(py1, py2),
                    px + pin_width / 2,
                    max(py1, py2),
                ),
                radius=pin_width / 2,
                fill=rgba("#8CEBFF", 255),
            )
            py = center[1] + offset * SCALE
            px1 = center[0] + direction * (chip_size // 2)
            px2 = center[0] + direction * (chip_size // 2 + pin_length)
            draw.rounded_rectangle(
                (
                    min(px1, px2),
                    py - pin_width / 2,
                    max(px1, px2),
                    py + pin_width / 2,
                ),
                radius=pin_width / 2,
                fill=rgba("#8CEBFF", 255),
            )

    # Pulse line inside the chip.
    pulse_points = [
        (center[0] - 51 * SCALE, center[1] + 3 * SCALE),
        (center[0] - 26 * SCALE, center[1] + 3 * SCALE),
        (center[0] - 13 * SCALE, center[1] - 25 * SCALE),
        (center[0] + 6 * SCALE, center[1] + 31 * SCALE),
        (center[0] + 24 * SCALE, center[1] + 3 * SCALE),
        (center[0] + 51 * SCALE, center[1] + 3 * SCALE),
    ]
    pulse_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pulse_draw = ImageDraw.Draw(pulse_layer)
    pulse_draw.line(
        pulse_points,
        fill=rgba("#FFFFFF", 245),
        width=9 * SCALE,
        joint="curve",
    )
    pulse_layer = pulse_layer.filter(ImageFilter.GaussianBlur(0.6 * SCALE))
    image.alpha_composite(Image.composite(pulse_layer, Image.new("RGBA", (size, size)), mask))
    draw = ImageDraw.Draw(image)

    # Small live dot above the chip.
    live_center = (center[0], center[1] - 57 * SCALE)
    draw.ellipse(
        (
            live_center[0] - 5 * SCALE,
            live_center[1] - 5 * SCALE,
            live_center[0] + 5 * SCALE,
            live_center[1] + 5 * SCALE,
        ),
        fill=rgba("#6BFFD2", 255),
    )

    # Inner hairline border.
    draw.rounded_rectangle(
        (margin + 2 * SCALE, margin + 2 * SCALE, size - margin - 2 * SCALE, size - margin - 2 * SCALE),
        radius=202 * SCALE,
        outline=rgba("#35455B", 255),
        width=3 * SCALE,
    )

    # Top glass highlight.
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle(
        box,
        radius=204 * SCALE,
        fill=rgba("#FFFFFF", 16),
    )
    hdraw.polygon(
        [
            (margin, margin),
            (size - margin, margin),
            (size - margin, 230 * SCALE),
            (margin, 340 * SCALE),
        ],
        fill=rgba("#000000", 65),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(26 * SCALE))
    image.alpha_composite(Image.composite(highlight, Image.new("RGBA", (size, size)), mask))

    # Clip everything to the rounded-square icon shape and make the interior opaque.
    final = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final.paste(image.convert("RGB"), (0, 0), mask)
    return final.resize((CANVAS, CANVAS), Image.LANCZOS)


def main() -> None:
    RESOURCES.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(parents=True, exist_ok=True)

    icon = draw_icon()
    icon.save(PNG_PATH)
    print(f"Wrote {PNG_PATH}")

    sizes = [16, 32, 32, 64, 128, 256, 256, 512, 512, 1024]
    names = [
        "icon_16x16.png",
        "icon_16x16@2x.png",
        "icon_32x32.png",
        "icon_32x32@2x.png",
        "icon_128x128.png",
        "icon_128x128@2x.png",
        "icon_256x256.png",
        "icon_256x256@2x.png",
        "icon_512x512.png",
        "icon_512x512@2x.png",
    ]

    with tempfile.TemporaryDirectory() as temporary:
        iconset = Path(temporary) / "AppIcon.iconset"
        iconset.mkdir()
        for size, name in zip(sizes, names):
            icon.resize((size, size), Image.LANCZOS).save(iconset / name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ICNS_PATH)], check=True)
    print(f"Wrote {ICNS_PATH}")


if __name__ == "__main__":
    main()
