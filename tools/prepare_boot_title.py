#!/usr/bin/env python3
"""Generate the three unified energy-fracture Boot title glyphs.

The 28-cell masks were traced once from Noto Sans SC at weight 800, then
frozen here so title generation stays deterministic and has no font or
platform dependency.  All styling is hard-edged and enlarged with nearest
neighbour sampling.
"""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from io import BytesIO
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATHS = {
    "bo_top": ROOT / "assets/ui/boot/title_bo_top.png",
    "bo_middle": ROOT / "assets/ui/boot/title_bo_middle.png",
    "zan_bottom": ROOT / "assets/ui/boot/title_zan_bottom.png",
}
LEGACY_PATHS = (
    ROOT / "assets/ui/boot/title_bobozan.png",
    ROOT / "assets/ui/boot/title_bobozan.png.import",
)

CELL_SIZE = 9
CANVAS_CELLS = (28, 28)
EXPECTED_SIZE = (
    CANVAS_CELLS[0] * CELL_SIZE,
    CANVAS_CELLS[1] * CELL_SIZE,
)

# Three-color adaptation of Lospec's "Baldur - Neon Darkness":
# https://lospec.com/palette-list/baldur-neon-darkness
TRANSPARENT = (0, 0, 0, 0)
STRUCTURE_INK = (15, 27, 38, 255)  # #0f1b26
IVORY_FACE = (245, 232, 209, 255)  # #f5e8d1
ENERGY_EDGE = (221, 86, 57, 255)  # #dd5639
PALETTE = {
    TRANSPARENT,
    STRUCTURE_INK,
    IVORY_FACE,
    ENERGY_EDGE,
}

# Upright, bold glyph skeletons.  These are deliberately more detailed than
# the rejected 24-cell hand sketch while retaining a clear pixel rhythm.
WAVE_GLYPH = (
    "............................",
    "............................",
    "............................",
    ".....###........###.........",
    ".....####.......###.........",
    "......####......###.........",
    ".......###.##############...",
    "..........###############...",
    "..........##############....",
    "..........####..###..###....",
    "....###...###...###..###....",
    "...######.####..###.........",
    "....####..#############.....",
    "......##..#############.....",
    "..........#############.....",
    "..........######....###.....",
    ".......##.#######..###......",
    "......###.###.########......",
    "......###.###..######.......",
    ".....####.###...#####.......",
    ".....###.####..######.......",
    "....####.###..#########.....",
    "....###..###.###########....",
    "....###.###..###....####....",
    "............................",
    "............................",
    "............................",
    "............................",
)

GATHER_GLYPH = (
    "............................",
    "............................",
    "............................",
    "......##...#.##.....##......",
    "......##..######.#######....",
    "......##..##############....",
    "......##..##.##..##.##......",
    "....#####################...",
    "...######################...",
    "...#######.#####..#####.....",
    ".....####..##.###.##.##.#...",
    "......##..##########.####...",
    "......##..#####..##..####...",
    "......####.......##...#.....",
    "....######.############.....",
    "...#######.############.....",
    "...######..###......###.....",
    ".....###...###..###.###.....",
    "......##...###..###.###.....",
    "......##...###..###.###.....",
    "......##....##.###...##.....",
    ".....###......#######.......",
    "....####..#######.######....",
    "....####..######....####....",
    "....###....##.........##....",
    "............................",
    "............................",
    "............................",
)


@dataclass(frozen=True)
class FaultStyle:
    """One shared fault rule with a per-glyph phase shift."""

    intercept: float
    slope: float = -0.20
    energy_min_x: int = 5


TITLE_STYLES = {
    # The repeated word uses the same skeleton but a slightly different fault
    # phase, so the pair feels related rather than duplicated.
    "bo_top": FaultStyle(intercept=10.6),
    "bo_middle": FaultStyle(intercept=9.8),
    # Keep the dense lower half and counters of "攒" away from the fault.
    "zan_bottom": FaultStyle(intercept=9.8, energy_min_x=7),
}


def _decode_glyph(rows: tuple[str, ...]) -> frozenset[tuple[int, int]]:
    if len(rows) != CANVAS_CELLS[1]:
        raise RuntimeError(f"Glyph must have {CANVAS_CELLS[1]} rows")
    if any(len(row) != CANVAS_CELLS[0] for row in rows):
        raise RuntimeError(f"Every glyph row must be {CANVAS_CELLS[0]} cells")
    if any(character not in ".#" for row in rows for character in row):
        raise RuntimeError("Glyph patterns may only contain '.' and '#'")
    return frozenset(
        (x, y)
        for y, row in enumerate(rows)
        for x, character in enumerate(row)
        if character == "#"
    )


def _bounds(cells: frozenset[tuple[int, int]]) -> tuple[int, int, int, int]:
    return (
        min(x for x, _ in cells),
        min(y for _, y in cells),
        max(x for x, _ in cells),
        max(y for _, y in cells),
    )


def _fault_y(x: int, style: FaultStyle) -> float:
    centre_x = (CANVAS_CELLS[0] - 1) * 0.5
    return style.intercept + style.slope * (x - centre_x)


def _apply_fault(
    glyph: frozenset[tuple[int, int]],
    style: FaultStyle,
) -> tuple[
    frozenset[tuple[int, int]],
    frozenset[tuple[int, int]],
    frozenset[tuple[int, int]],
    frozenset[tuple[int, int]],
]:
    """Cut one transparent seam and return face plus its two exposed lips."""

    fracture = frozenset(
        (x, y)
        for x, y in glyph
        if abs(y - _fault_y(x, style)) <= 0.55
    )
    styled = glyph - fracture

    def touches_fracture(cell: tuple[int, int]) -> bool:
        x, y = cell
        return any(
            (x + dx, y + dy) in fracture
            for dy in (-1, 0, 1)
            for dx in (-1, 0, 1)
            if dx != 0 or dy != 0
        )

    energy = frozenset(
        (x, y)
        for x, y in styled
        if (
            -1.65 <= y - _fault_y(x, style) < -0.55
            and x >= style.energy_min_x
            and touches_fracture((x, y))
        )
    )
    structure_lip = frozenset(
        (x, y)
        for x, y in styled
        if (
            0.55 < y - _fault_y(x, style) <= 1.65
            and touches_fracture((x, y))
        )
    )
    if not fracture or not energy or not structure_lip:
        raise RuntimeError(
            "Energy fault must contain a seam and two exposed lips"
        )
    return styled, fracture, structure_lip, energy


def _render_glyph(
    glyph: frozenset[tuple[int, int]],
    style: FaultStyle,
) -> tuple[
    Image.Image,
    frozenset[tuple[int, int]],
    frozenset[tuple[int, int]],
    frozenset[tuple[int, int]],
    frozenset[tuple[int, int]],
]:
    styled, fracture, structure_lip, energy = _apply_fault(glyph, style)
    logical = Image.new("RGBA", CANVAS_CELLS, TRANSPARENT)

    # A single down-right dark slab supplies structure without a uniform
    # outline.  The ivory face then covers every non-exposed shadow pixel.
    depth = frozenset((x + 1, y + 1) for x, y in styled)
    for x, y in depth:
        if (
            0 <= x < CANVAS_CELLS[0]
            and 0 <= y < CANVAS_CELLS[1]
            and (x, y) not in fracture
        ):
            logical.putpixel((x, y), STRUCTURE_INK)
    for x, y in styled:
        logical.putpixel((x, y), IVORY_FACE)
    for x, y in structure_lip:
        logical.putpixel((x, y), STRUCTURE_INK)
    for x, y in energy:
        logical.putpixel((x, y), ENERGY_EDGE)
    # A final clear pass prevents the down-right structural slab from ever
    # leaking back into the intended transparent seam.
    for x, y in fracture:
        logical.putpixel((x, y), TRANSPARENT)

    enlarged = logical.resize(EXPECTED_SIZE, Image.Resampling.NEAREST)
    return enlarged, styled, fracture, structure_lip, energy


def _encode_png(image: Image.Image) -> bytes:
    buffer = BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def build_titles(
) -> dict[
    str,
    tuple[
        Image.Image,
        frozenset[tuple[int, int]],
        frozenset[tuple[int, int]],
        frozenset[tuple[int, int]],
        frozenset[tuple[int, int]],
    ],
]:
    wave = _decode_glyph(WAVE_GLYPH)
    gather = _decode_glyph(GATHER_GLYPH)
    glyphs = {
        "bo_top": wave,
        "bo_middle": wave,
        "zan_bottom": gather,
    }
    return {
        name: _render_glyph(glyph, TITLE_STYLES[name])
        for name, glyph in glyphs.items()
    }


def _validate(
    image: Image.Image,
    styled: frozenset[tuple[int, int]],
    fracture: frozenset[tuple[int, int]],
    structure_lip: frozenset[tuple[int, int]],
    energy: frozenset[tuple[int, int]],
    label: str,
) -> None:
    if image.mode != "RGBA":
        raise RuntimeError(f"Expected RGBA output, got {image.mode}")
    if image.size != EXPECTED_SIZE:
        raise RuntimeError(
            f"Unexpected title size: {image.size}, wanted {EXPECTED_SIZE}"
        )

    used_colors = set(image.get_flattened_data())
    if used_colors != PALETTE:
        unexpected = used_colors - PALETTE
        missing = PALETTE - used_colors
        raise RuntimeError(
            f"Palette mismatch; unexpected={unexpected}, missing={missing}"
        )

    alpha = image.getchannel("A")
    corners = (
        alpha.getpixel((0, 0)),
        alpha.getpixel((image.width - 1, 0)),
        alpha.getpixel((0, image.height - 1)),
        alpha.getpixel((image.width - 1, image.height - 1)),
    )
    if any(corners):
        raise RuntimeError(f"Title corners must stay transparent: {corners}")

    min_x, min_y, max_x, max_y = _bounds(styled)
    if min_x < 2 or min_y < 2 or max_x > 25 or max_y > 25:
        raise RuntimeError(
            f"{label} fault left its one-cell depth safety border"
        )

    energy_ratio = len(energy) / len(styled)
    fracture_ratio = len(fracture) / (len(styled) + len(fracture))
    structure_ratio = len(structure_lip) / len(styled)
    if not 0.02 <= energy_ratio <= 0.08:
        raise RuntimeError(
            f"{label} energy edge ratio is not restrained: {energy_ratio:.3%}"
        )
    if not 0.02 <= fracture_ratio <= 0.07:
        raise RuntimeError(
            f"{label} fracture ratio is not restrained: "
            f"{fracture_ratio:.3%}"
        )
    if not 0.02 <= structure_ratio <= 0.10:
        raise RuntimeError(
            f"{label} structure lip ratio is not restrained: "
            f"{structure_ratio:.3%}"
        )

    logical = image.resize(
        CANVAS_CELLS,
        Image.Resampling.NEAREST,
    )
    for cell in fracture:
        if logical.getpixel(cell) != TRANSPARENT:
            raise RuntimeError(
                f"{label} fracture was refilled at {cell}: "
                f"{logical.getpixel(cell)}"
            )
    for pixel in logical.get_flattened_data():
        if pixel[3] == 0 and pixel != TRANSPARENT:
            raise RuntimeError(
                f"{label} contains transparent pixels with dirty RGB values"
            )


def main() -> None:
    titles = build_titles()
    validations = {
        "bo_top": "top wave",
        "bo_middle": "middle wave",
        "zan_bottom": "bottom gather",
    }

    encoded: dict[str, bytes] = {}
    for name, (
        image,
        styled,
        fracture,
        structure_lip,
        energy,
    ) in titles.items():
        _validate(
            image,
            styled,
            fracture,
            structure_lip,
            energy,
            validations[name],
        )
        encoded[name] = _encode_png(image)

    repeated = build_titles()
    repeated_encoded = {
        name: _encode_png(result[0])
        for name, result in repeated.items()
    }
    if encoded != repeated_encoded:
        raise RuntimeError("Repeated title generation is not byte-stable")
    if encoded["bo_top"] == encoded["bo_middle"]:
        raise RuntimeError("The two wave fault phases must differ")

    OUTPUT_PATHS["bo_top"].parent.mkdir(parents=True, exist_ok=True)
    for name, output_path in OUTPUT_PATHS.items():
        png = encoded[name]
        output_path.write_bytes(png)
        digest = sha256(png).hexdigest()
        image = titles[name][0]
        print(
            f"Wrote {output_path.relative_to(ROOT)} "
            f"({image.width}x{image.height}, RGBA, sha256={digest})"
        )

    for legacy_path in LEGACY_PATHS:
        if legacy_path.exists():
            legacy_path.unlink()
            print(f"Removed {legacy_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
