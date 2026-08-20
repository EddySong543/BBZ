#!/usr/bin/env python3
"""Normalize a generated Scene6 lava greatsword into a true 28x64 sprite."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image


LOGICAL_SIZE = (28, 64)
CONTENT_SIZE = (26, 62)
ALPHA_THRESHOLD = 96
PALETTE: tuple[tuple[int, int, int, int], ...] = (
    (14, 8, 12, 255),      # charcoal outline
    (35, 24, 29, 255),     # black iron
    (70, 52, 58, 255),     # worn iron face
    (92, 17, 22, 255),     # deep oxblood
    (151, 34, 17, 255),    # molten red
    (218, 65, 15, 255),    # burnt orange
    (255, 119, 22, 255),   # hot orange
    (255, 207, 74, 255),   # tiny core gold
)


def _color_distance_squared(
    source: tuple[int, int, int], target: tuple[int, int, int, int]
) -> float:
    red_weight = 1.18
    green_weight = 1.0
    blue_weight = 0.84
    return (
        (source[0] - target[0]) ** 2 * red_weight
        + (source[1] - target[1]) ** 2 * green_weight
        + (source[2] - target[2]) ** 2 * blue_weight
    )


def normalize(source_path: Path) -> Image.Image:
    with Image.open(source_path) as opened:
        source = opened.convert("RGBA")
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("source contains no opaque sword pixels")
    cropped = source.crop(bbox)
    scale = min(
        CONTENT_SIZE[0] / cropped.width,
        CONTENT_SIZE[1] / cropped.height,
    )
    fitted_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    fitted = (
        cropped.convert("RGBa")
        .resize(fitted_size, Image.Resampling.BOX)
        .convert("RGBA")
    )
    result = Image.new("RGBA", LOGICAL_SIZE, (0, 0, 0, 0))
    origin = (
        (LOGICAL_SIZE[0] - fitted.width) // 2,
        (LOGICAL_SIZE[1] - fitted.height) // 2,
    )
    result.alpha_composite(fitted, origin)
    pixels = result.load()
    warm_candidates: list[tuple[float, int, int]] = []
    opaque_count = 0
    for y_index in range(result.height):
        for x_index in range(result.width):
            red, green, blue, alpha = pixels[x_index, y_index]
            if alpha < ALPHA_THRESHOLD:
                pixels[x_index, y_index] = (0, 0, 0, 0)
                continue
            opaque_count += 1
            if red >= green * 0.95 and green >= blue * 1.25:
                warm_candidates.append(
                    (red + green * 1.45 - blue * 0.55, x_index, y_index)
                )
            nearest = min(
                PALETTE,
                key=lambda candidate: _color_distance_squared(
                    (red, green, blue), candidate
                ),
            )
            pixels[x_index, y_index] = nearest
    # BOX downsampling can reduce tiny yellow cores to orange. Reserve a very
    # small fixed share of the hottest warm samples so the legendary seam
    # remains readable without turning the blade into a uniformly gold prop.
    desired_core_count = max(4, math.ceil(opaque_count * 0.015))
    current_core_count = sum(
        1 for pixel in result.get_flattened_data() if pixel == PALETTE[-1]
    )
    warm_candidates.sort(reverse=True)
    for _score, x_index, y_index in warm_candidates:
        if current_core_count >= desired_core_count:
            break
        if pixels[x_index, y_index] != PALETTE[-1]:
            pixels[x_index, y_index] = PALETTE[-1]
            current_core_count += 1
    return _refine_forge_silhouette(result)


def _refine_forge_silhouette(source: Image.Image) -> Image.Image:
    """Keep generated contour/detail, but restore a readable low-res blade mass."""
    result = source.copy()
    pixels = result.load()
    for y_index in range(1, 44):
        if y_index <= 3:
            half_width = 1
        elif y_index <= 6:
            half_width = 2
        elif y_index <= 10:
            half_width = 4
        elif y_index <= 38:
            half_width = 6
        else:
            half_width = 5 - ((y_index - 39) // 2)
        center = 13 + (1 if y_index in (9, 10, 23, 24, 37) else 0)
        left = center - half_width
        right = center + half_width
        if y_index in (15, 16, 31, 32):
            left += 1
        if y_index in (19, 20, 35, 36):
            right -= 1
        for x_index in range(left, right + 1):
            if x_index < 0 or x_index >= result.width:
                continue
            if pixels[x_index, y_index][3] != 0:
                continue
            edge_distance = min(x_index - left, right - x_index)
            if edge_distance == 0:
                color = PALETTE[0]
            elif edge_distance == 1:
                color = PALETTE[2] if (y_index // 4 + x_index) % 3 == 0 else PALETTE[1]
            elif x_index in (center, center + 1) and y_index > 10:
                color = PALETTE[3]
            else:
                color = PALETTE[1]
            pixels[x_index, y_index] = color

    main_seam = {
        3: 13, 5: 14, 7: 13, 9: 14, 11: 13, 13: 14, 15: 13,
        17: 12, 19: 13, 21: 12, 23: 13, 25: 14, 27: 13,
        29: 14, 31: 13, 33: 12, 35: 13, 37: 12, 39: 13, 41: 12,
    }
    gold_rows = {9, 19, 31, 39}
    for y_index, x_index in main_seam.items():
        pixels[x_index, y_index] = (
            PALETTE[-1] if y_index in gold_rows
            else PALETTE[6] if y_index % 4 == 1
            else PALETTE[5]
        )
        if y_index + 1 < 44:
            pixels[x_index, y_index + 1] = PALETTE[4]

    branch_pixels = (
        (14, 15, 5), (15, 16, 6), (16, 17, 4),
        (21, 11, 5), (22, 10, 4), (23, 9, 4),
        (27, 15, 5), (28, 16, 6), (29, 17, 4),
        (35, 11, 5), (36, 10, 4), (37, 9, 4),
    )
    for y_index, x_index, palette_index in branch_pixels:
        if pixels[x_index, y_index][3] != 0:
            pixels[x_index, y_index] = PALETTE[palette_index]
    return result


def validate(image: Image.Image) -> list[str]:
    failures: list[str] = []
    rgba = image.convert("RGBA")
    if rgba.size != LOGICAL_SIZE:
        failures.append(f"size {rgba.size}, expected {LOGICAL_SIZE}")
    alpha_values = set(rgba.getchannel("A").get_flattened_data())
    if not alpha_values.issubset({0, 255}):
        failures.append(f"non-binary alpha: {sorted(alpha_values)[:8]}")
    opaque = [pixel for pixel in rgba.get_flattened_data() if pixel[3] == 255]
    colors = set(opaque)
    if not colors.issubset(set(PALETTE)):
        failures.append("sprite contains colors outside the Scene6 forge palette")
    if not 150 <= len(opaque) <= 620:
        failures.append(f"opaque pixel count {len(opaque)} is outside 150..620")
    core_pixels = sum(1 for pixel in opaque if pixel == PALETTE[-1])
    core_ratio = core_pixels / max(len(opaque), 1)
    if not 0.01 <= core_ratio <= 0.08:
        failures.append(f"core-gold ratio {core_ratio:.4f} is outside 0.01..0.08")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        failures.append("sprite is fully transparent")
    else:
        width = bbox[2] - bbox[0]
        height = bbox[3] - bbox[1]
        if width < 16 or height < 56:
            failures.append(f"silhouette bounds {width}x{height} are too small")
        row_widths = [
            sum(1 for x_index in range(rgba.width)
                if rgba.getpixel((x_index, y_index))[3] == 255)
            for y_index in range(rgba.height)
        ]
        widest_row = max(range(len(row_widths)), key=row_widths.__getitem__)
        if widest_row < int(rgba.height * 0.60):
            failures.append(
                f"widest guard row {widest_row} must sit in the lower 40 percent"
            )
    return failures


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="generated transparent source PNG")
    parser.add_argument("--output", type=Path, required=True, help="formal output PNG")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    if args.check:
        if not args.output.is_file():
            raise SystemExit(f"missing output: {args.output}")
        with Image.open(args.output) as opened:
            failures = validate(opened)
    else:
        if args.input is None or not args.input.is_file():
            raise SystemExit("--input must name an existing transparent PNG")
        result = normalize(args.input)
        failures = validate(result)
        if not failures:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            result.save(args.output, format="PNG", optimize=False, compress_level=9)

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}")
        raise SystemExit(1)
    print(f"Scene6 molten greatsword valid: {args.output} | 28x64 | palette<=8")


if __name__ == "__main__":
    main()
