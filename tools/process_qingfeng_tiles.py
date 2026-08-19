"""Normalize approved Qingfeng Ricefield image-gen sources into Godot tiles."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


TILES = {
    "grass_alpha.png": ("grass_01.png", "ground"),
    "rice_alpha.png": ("rice_01.png", "object"),
    "dirt_alpha.png": ("dirt_path_01.png", "ground"),
    "boundary_alpha.png": ("field_boundary_01.png", "object"),
    "search_alpha.png": ("search_supply_01.png", "object"),
}

GRASS_VARIANTS = {
    "grass_light_01_source.png": "grass_light_01.png",
    "grass_light_02_source.png": "grass_light_02.png",
    "grass_dark_01_source.png": "grass_dark_01.png",
    "grass_dark_02_source.png": "grass_dark_02.png",
}

# Image generation supplies texture detail; this small deterministic calibration
# keeps the four sources inside the approved Ref37 olive-green value range.
GRASS_CHANNEL_SCALE = {
    "light": (0.72, 0.84, 0.90),
    "dark": (1.50, 1.68, 1.05),
}

OUTPUT_SIZE = 128
PADDING_RATIO = 0.018
PREVIEW_TILE_SIZE = 256


def clear_magenta_spill(image: Image.Image) -> Image.Image:
    """Drop residual chroma-key shadow pixels without touching farm colors."""
    cleaned = image.copy()
    pixels = []
    for red, green, blue, alpha in cleaned.get_flattened_data():
        magenta_dominant = (
            alpha > 0
            and red > 70
            and blue > 70
            and red > green * 1.35
            and blue > green * 1.25
        )
        pixels.append((red, green, blue, 0) if magenta_dominant else (red, green, blue, alpha))
    cleaned.putdata(pixels)
    return cleaned


def normalize_tile(source: Path, destination: Path, layer_kind: str) -> None:
    image = clear_magenta_spill(Image.open(source).convert("RGBA"))
    visible_alpha = image.getchannel("A").point(lambda value: 255 if value >= 64 else 0)
    bbox = visible_alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{source} has no visible pixels")

    if layer_kind == "ground":
        cropped = image.crop(bbox)
        side = max(cropped.width, cropped.height)
        padding = max(2, round(side * PADDING_RATIO))
        canvas_side = side + padding * 2
        canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
        offset = ((canvas_side - cropped.width) // 2, (canvas_side - cropped.height) // 2)
        canvas.alpha_composite(cropped, offset)
        result = canvas.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.NEAREST)
    elif layer_kind == "object":
        # Preserve the generated transparent canvas so reusable objects keep their
        # intended footprint instead of expanding to fill the whole cell.
        result = image.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.NEAREST)
    else:
        raise ValueError(f"unknown layer kind: {layer_kind}")

    if any(result.getpixel(point)[3] != 0 for point in ((0, 0), (127, 0), (0, 127), (127, 127))):
        raise ValueError(f"{source} does not have transparent corners")

    destination.parent.mkdir(parents=True, exist_ok=True)
    result.save(destination, format="PNG", optimize=False)
    print(f"Wrote {destination} ({result.mode} {result.size[0]}x{result.size[1]})")


def normalize_grass_variant(source: Path, destination: Path) -> None:
    """Center-crop an image-gen grass surface without inventing tile borders."""
    image = Image.open(source).convert("RGBA")
    side = min(image.width, image.height)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    square = image.crop((left, top, left + side, top + side))
    result = square.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    family = "light" if "light" in destination.stem else "dark"
    red, green, blue, alpha = result.split()
    scales = GRASS_CHANNEL_SCALE[family]
    red = red.point(lambda value: min(255, round(value * scales[0])))
    green = green.point(lambda value: min(255, round(value * scales[1])))
    blue = blue.point(lambda value: min(255, round(value * scales[2])))
    result = Image.merge("RGBA", (red, green, blue, alpha))
    destination.parent.mkdir(parents=True, exist_ok=True)
    result.save(destination, format="PNG", optimize=False)
    print(f"Wrote {destination} ({result.mode} {result.size[0]}x{result.size[1]})")


def compose_preview(output_dir: Path, preview_path: Path) -> None:
    cells = [
        ("grass_01.png", None), ("grass_01.png", "rice_01.png"), ("dirt_path_01.png", None),
        ("grass_01.png", "field_boundary_01.png"),
        ("grass_01.png", "search_supply_01.png"),
        ("dirt_path_01.png", "search_supply_01.png"),
        ("grass_01.png", "rice_01.png"),
        ("grass_01.png", "field_boundary_01.png"),
        ("dirt_path_01.png", None),
    ]
    preview = Image.new(
        "RGBA",
        (PREVIEW_TILE_SIZE * 3, PREVIEW_TILE_SIZE * 3),
        (23, 17, 10, 255),
    )
    for index, (ground_name, object_name) in enumerate(cells):
        tile = Image.open(output_dir / ground_name).convert("RGBA")
        tile = tile.resize((PREVIEW_TILE_SIZE, PREVIEW_TILE_SIZE), Image.Resampling.NEAREST)
        if object_name is not None:
            overlay = Image.open(output_dir / object_name).convert("RGBA")
            overlay = overlay.resize((PREVIEW_TILE_SIZE, PREVIEW_TILE_SIZE), Image.Resampling.NEAREST)
            tile.alpha_composite(overlay)
        position = ((index % 3) * PREVIEW_TILE_SIZE, (index // 3) * PREVIEW_TILE_SIZE)
        preview.alpha_composite(tile, position)
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(preview_path, format="PNG", optimize=False)
    print(f"Wrote {preview_path} ({preview.size[0]}x{preview.size[1]})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path)
    parser.add_argument("--grass-variants-dir", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()

    if args.input_dir is None and args.grass_variants_dir is None:
        parser.error("provide --input-dir and/or --grass-variants-dir")
    if args.input_dir is not None:
        for source_name, (destination_name, layer_kind) in TILES.items():
            normalize_tile(args.input_dir / source_name, args.output_dir / destination_name, layer_kind)
    if args.grass_variants_dir is not None:
        for source_name, destination_name in GRASS_VARIANTS.items():
            normalize_grass_variant(
                args.grass_variants_dir / source_name,
                args.output_dir / destination_name,
            )
    if args.preview is not None:
        compose_preview(args.output_dir, args.preview)


if __name__ == "__main__":
    main()
