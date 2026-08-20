"""Reduce generated left-edge bookmark sources into hard-edged 2x pixel UI textures."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


PAPER_PALETTE = (
    (151, 98, 51, 255),   # embedded fibres / deepest paper mark
    (176, 126, 68, 255),
    (198, 153, 88, 255),
    (217, 179, 116, 255),
    (232, 204, 151, 255),
    (242, 222, 184, 255),
    (248, 233, 204, 255),
)
OUTER_EDGE = (68, 42, 23, 255)
INNER_EDGE = (128, 82, 42, 255)
SEAM_DARK = (106, 66, 34, 255)
SEAM_LIGHT = (224, 190, 128, 255)


def _left_inset(y: int, height: int) -> int:
    """Small stepped chamfer only on the exposed LEFT end."""
    distance = min(y, height - 1 - y)
    if distance == 0:
        return 6
    if distance == 1:
        return 5
    if distance == 2:
        return 4
    if distance == 3:
        return 3
    if distance == 4:
        return 2
    if distance == 5:
        return 1
    return 0


def _is_inside(x: int, y: int, width: int, height: int) -> bool:
    return 0 <= y < height and x >= _left_inset(y, height) and x < width


def _is_boundary(x: int, y: int, width: int, height: int) -> bool:
    if not _is_inside(x, y, width, height):
        return False
    return any(
        not _is_inside(nx, ny, width, height)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
    )


def _is_inner_boundary(x: int, y: int, width: int, height: int) -> bool:
    if not _is_inside(x, y, width, height) or _is_boundary(x, y, width, height):
        return False
    return any(
        _is_boundary(nx, ny, width, height)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
        if 0 <= nx < width and 0 <= ny < height
    )


def reduce_source(source_path: Path, output_path: Path, logical_size: tuple[int, int]) -> None:
    with Image.open(source_path) as source:
        rgba = source.convert("RGBA")
        alpha = rgba.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise ValueError(f"source has no visible pixels: {source_path}")
        trimmed = rgba.crop(bbox)
        reduced = trimmed.resize(logical_size, Image.Resampling.LANCZOS).convert("RGB")
        luminance = ImageOps.autocontrast(reduced.convert("L"), cutoff=2)

    out = Image.new("RGBA", logical_size, (0, 0, 0, 0))
    width, height = logical_size
    for y in range(logical_size[1]):
        for x in range(logical_size[0]):
            if not _is_inside(x, y, width, height):
                continue
            value = luminance.getpixel((x, y))
            palette_index = min(value * len(PAPER_PALETTE) // 256, len(PAPER_PALETTE) - 1)
            color = PAPER_PALETTE[palette_index]
            if _is_boundary(x, y, width, height):
                color = OUTER_EDGE
            elif _is_inner_boundary(x, y, width, height):
                color = INNER_EDGE
            out.putpixel((x, y), color)

    # Right side is the insertion throat: square corners plus one compressed seam.
    seam_x = width - max(7, width // 8)
    for y in range(2, height - 2):
        out.putpixel((seam_x, y), SEAM_DARK)
        out.putpixel((seam_x + 1, y), SEAM_LIGHT)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    out.resize((width * 2, height * 2), Image.Resampling.NEAREST).save(output_path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--chapter-source", type=Path, required=True)
    parser.add_argument("--rarity-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    reduce_source(args.chapter_source, args.output_dir / "bookmark_chapter_left.png", (74, 24))
    reduce_source(args.rarity_source, args.output_dir / "bookmark_rarity_left.png", (51, 16))


if __name__ == "__main__":
    main()
