"""Normalize generated Qingfeng plant overlays into crisp 60x60 Godot sprites."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CANVAS_SIZE = 60
ALPHA_THRESHOLD = 96
COMPONENT_RATIO = 0.05


SPECS = {
    "flower_white": (24, 30, 45),
    "flower_yellow": (24, 30, 45),
    "flower_pink": (24, 30, 45),
    "short_grass": (26, 16, 42),
    "clover": (26, 20, 43),
}


def _kept_component_mask(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    pixels = alpha.load()
    width, height = image.size
    visited: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []

    for y in range(height):
        for x in range(width):
            point = (x, y)
            if point in visited or pixels[x, y] < ALPHA_THRESHOLD:
                continue
            stack = [point]
            visited.add(point)
            component: list[tuple[int, int]] = []
            while stack:
                current_x, current_y = stack.pop()
                component.append((current_x, current_y))
                for offset_x, offset_y in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    neighbor = (current_x + offset_x, current_y + offset_y)
                    if (
                        0 <= neighbor[0] < width
                        and 0 <= neighbor[1] < height
                        and neighbor not in visited
                        and pixels[neighbor[0], neighbor[1]] >= ALPHA_THRESHOLD
                    ):
                        visited.add(neighbor)
                        stack.append(neighbor)

            components.append(component)

    if not components:
        raise ValueError("overlay source has no opaque subject")

    largest_size = max(len(component) for component in components)
    mask = Image.new("L", image.size, 0)
    mask_pixels = mask.load()
    for component in components:
        if len(component) < largest_size * COMPONENT_RATIO:
            continue
        for x, y in component:
            mask_pixels[x, y] = 255
    return mask


def normalize(source: Path, destination: Path, spec_name: str) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    cleaned_pixels = []
    for red, green, blue, alpha in image.get_flattened_data():
        key_spill = (
            alpha > 0
            and red > 110
            and blue > 110
            and red > green * 1.7
            and blue > green * 1.7
            and abs(red - blue) < 90
        )
        cleaned_pixels.append((red, green, blue, 0) if key_spill else (red, green, blue, alpha))
    image.putdata(cleaned_pixels)
    mask = _kept_component_mask(image)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError(f"{source} has no retained subject")

    cropped = image.crop(bbox)
    cropped.putalpha(mask.crop(bbox))
    max_width, max_height, baseline = SPECS[spec_name]
    scale = min(max_width / cropped.width, max_height / cropped.height)
    target_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    # BOX retains the generated block proportions while reducing the large source.
    # Quantization and binary alpha below turn the result back into hard pixels.
    sprite = cropped.resize(target_size, Image.Resampling.BOX)
    sprite = sprite.quantize(
        colors=10,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    hard_alpha = sprite.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    sprite.putalpha(hard_alpha)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    offset = ((CANVAS_SIZE - sprite.width) // 2, baseline - sprite.height)
    canvas.alpha_composite(sprite, offset)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, format="PNG", optimize=False)
    print(
        f"Wrote {destination} ({CANVAS_SIZE}x{CANVAS_SIZE}, "
        f"subject={sprite.width}x{sprite.height}, offset={offset})"
    )
    return canvas


def compose_preview(
    ground_path: Path,
    overlays: list[Image.Image],
    destination: Path,
) -> None:
    ground = Image.open(ground_path).convert("RGBA")
    scale = 4
    gap = 16
    tile_size = CANVAS_SIZE * scale
    preview = Image.new(
        "RGBA",
        (tile_size * len(overlays) + gap * (len(overlays) - 1), tile_size),
        (12, 18, 12, 255),
    )
    for index, overlay in enumerate(overlays):
        cell = ground.copy()
        cell.alpha_composite(overlay)
        cell = cell.resize((tile_size, tile_size), Image.Resampling.NEAREST)
        preview.alpha_composite(cell, (index * (tile_size + gap), 0))
    destination.parent.mkdir(parents=True, exist_ok=True)
    preview.save(destination, format="PNG", optimize=False)
    print(f"Wrote {destination} ({preview.width}x{preview.height})")


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in SPECS:
        parser.add_argument(f"--{name.replace('_', '-')}", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--ground", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    overlays: list[Image.Image] = []
    for name in SPECS:
        source = getattr(args, name)
        overlays.append(normalize(source, args.output_dir / f"overlay_{name}_v1.png", name))
    compose_preview(args.ground, overlays, args.preview)


if __name__ == "__main__":
    main()
