"""Build preview-faithful hard-edged codex bookmark state textures.

The generated parchment source supplies only paper luminance and fibres. Geometry,
state contrast, hard alpha, shadow, and exact 2x scaling are deterministic so the
runtime result cannot drift from the approved preview proportions.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


EDGE = (66, 43, 28, 255)
INNER_EDGE = (121, 82, 49, 255)
ROOT_DARK = (76, 49, 31, 255)
SHADOW_DARK = (45, 30, 22, 255)
SHADOW_SOFT = (73, 50, 35, 255)

IDLE_DARK = (124, 88, 55)
IDLE_LIGHT = (203, 171, 119)
SELECTED_DARK = (145, 101, 59)
SELECTED_LIGHT = (226, 197, 146)


def _lerp_color(low: tuple[int, int, int], high: tuple[int, int, int], amount: float) -> tuple[int, int, int, int]:
    amount = max(0.0, min(1.0, amount))
    return tuple(round(low[index] + (high[index] - low[index]) * amount) for index in range(3)) + (255,)


def _paper_field(source: Image.Image, size: tuple[int, int], selected: bool) -> Image.Image:
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("bookmark source contains no visible paper")
    trimmed = source.crop(bbox).convert("RGB")
    luminance = ImageOps.autocontrast(
        trimmed.resize(size, Image.Resampling.LANCZOS).convert("L"), cutoff=1
    )
    dark, light = (SELECTED_DARK, SELECTED_LIGHT) if selected else (IDLE_DARK, IDLE_LIGHT)
    field = Image.new("RGBA", size)
    for y in range(size[1]):
        for x in range(size[0]):
            value = luminance.getpixel((x, y))
            band = round((value / 255.0) * 11.0) / 11.0
            field.putpixel((x, y), _lerp_color(dark, light, band))
    return field


def _chapter_left(y: int, selected: bool) -> int:
    if selected:
        return {1: 5, 2: 3, 3: 2, 4: 1, 31: 1, 32: 3}.get(y, 0)
    return 15 + {3: 3, 4: 2, 5: 1, 29: 1, 30: 2}.get(y, 0)


def _rarity_left(y: int, selected: bool) -> int:
    if selected:
        return {2: 3, 3: 1, 20: 1, 21: 3}.get(y, 0)
    return 9 + {3: 2, 4: 1, 19: 1, 20: 2}.get(y, 0)


def _paper_bounds(kind: str, selected: bool) -> tuple[int, int, int, int]:
    if kind == "chapter":
        return (0 if selected else 15, 1 if selected else 3, 92, 33 if selected else 31)
    return (0 if selected else 9, 2 if selected else 3, 58, 22 if selected else 21)


def _left_for(kind: str, y: int, selected: bool) -> int:
    return _chapter_left(y, selected) if kind == "chapter" else _rarity_left(y, selected)


def _inside(kind: str, x: int, y: int, selected: bool) -> bool:
    _, top, right, bottom = _paper_bounds(kind, selected)
    return top <= y < bottom and _left_for(kind, y, selected) <= x < right


def _boundary(kind: str, x: int, y: int, selected: bool) -> bool:
    if not _inside(kind, x, y, selected):
        return False
    return any(
        not _inside(kind, nx, ny, selected)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
    )


def _inner_boundary(kind: str, x: int, y: int, selected: bool) -> bool:
    if not _inside(kind, x, y, selected) or _boundary(kind, x, y, selected):
        return False
    return any(
        _boundary(kind, nx, ny, selected)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
    )


def build_state(source: Image.Image, kind: str, selected: bool) -> Image.Image:
    logical_size = (92, 36) if kind == "chapter" else (58, 24)
    _, top, right, bottom = _paper_bounds(kind, selected)
    left_min = 0 if selected else (15 if kind == "chapter" else 9)
    field = _paper_field(source, (right - left_min, bottom - top), selected)
    out = Image.new("RGBA", logical_size, (0, 0, 0, 0))

    shadow_offset = 3 if kind == "chapter" else 2
    for y in range(logical_size[1]):
        for x in range(logical_size[0]):
            if _inside(kind, x, y - shadow_offset, selected):
                out.putpixel((x, y), SHADOW_SOFT if (x + y) % 3 else SHADOW_DARK)

    for y in range(logical_size[1]):
        for x in range(logical_size[0]):
            if not _inside(kind, x, y, selected):
                continue
            source_x = max(0, min(field.width - 1, x - left_min))
            source_y = max(0, min(field.height - 1, y - top))
            color = field.getpixel((source_x, source_y))
            if _boundary(kind, x, y, selected):
                color = EDGE
            elif _inner_boundary(kind, x, y, selected):
                color = INNER_EDGE
            out.putpixel((x, y), color)

    for y in range(top + 1, bottom - 1):
        out.putpixel((logical_size[0] - 4, y), ROOT_DARK)
        out.putpixel((logical_size[0] - 3, y), INNER_EDGE)

    return out.resize((logical_size[0] * 2, logical_size[1] * 2), Image.Resampling.NEAREST)


def extract_icon(preview: Image.Image, crop: tuple[int, int, int, int], output_size: tuple[int, int]) -> Image.Image:
    source = ImageOps.fit(preview.crop(crop).convert("RGB"), output_size, method=Image.Resampling.LANCZOS)
    luminance = source.convert("L")
    icon = Image.new("RGBA", output_size, (0, 0, 0, 0))
    for y in range(output_size[1]):
        for x in range(output_size[0]):
            value = luminance.getpixel((x, y))
            if value < 105:
                level = 38 if value < 55 else 58 if value < 80 else 82
                icon.putpixel((x, y), (level, round(level * 0.72), round(level * 0.5), 255))
    return icon


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--chapter-source", type=Path, required=True)
    parser.add_argument("--rarity-source", type=Path, required=True)
    parser.add_argument("--preview-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    with Image.open(args.chapter_source) as chapter_source:
        chapter_rgba = chapter_source.convert("RGBA")
        build_state(chapter_rgba, "chapter", False).save(args.output_dir / "bookmark_chapter_idle.png", optimize=True)
        build_state(chapter_rgba, "chapter", True).save(args.output_dir / "bookmark_chapter_selected.png", optimize=True)
    with Image.open(args.rarity_source) as rarity_source:
        rarity_rgba = rarity_source.convert("RGBA")
        build_state(rarity_rgba, "rarity", False).save(args.output_dir / "bookmark_rarity_idle.png", optimize=True)
        build_state(rarity_rgba, "rarity", True).save(args.output_dir / "bookmark_rarity_selected.png", optimize=True)
    with Image.open(args.preview_source) as preview_source:
        preview = preview_source.convert("RGB")
        extract_icon(preview, (122, 214, 151, 245), (32, 32)).save(args.output_dir / "bookmark_icon_hero.png", optimize=True)
        extract_icon(preview, (109, 292, 147, 332), (34, 34)).save(args.output_dir / "bookmark_icon_item.png", optimize=True)


if __name__ == "__main__":
    main()
