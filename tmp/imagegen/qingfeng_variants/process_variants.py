from pathlib import Path

from PIL import Image


ROOT = Path("assets/tilesets/qingfeng_ricefield/candidates")
SPECS = {
    "wheat": ("wheat_scheme1_v3.png", 12),
    "stone": ("stone_scheme1_v2.png", 8),
    "grass": ("grass_scheme1_v2.png", 8),
}
PREVIEW = Path("D:/Game/BoBoZan/_probe_output/qingfeng_tile_variants_preview.png")


def calibrate_wheat(tile: Image.Image, alpha: Image.Image) -> Image.Image:
    calibrated = Image.new("RGBA", tile.size, (0, 0, 0, 0))
    output_pixels: list[tuple[int, int, int, int]] = []
    for pixel, alpha_value in zip(tile.get_flattened_data(), alpha.get_flattened_data()):
        if alpha_value == 0:
            output_pixels.append((0, 0, 0, 0))
            continue
        red, green, blue, _ = pixel
        value = max(red, green, blue)
        is_wheat = red > 145 and red >= green * 0.98 and blue < green * 0.68
        if value < 78:
            color = (42, 49, 8)
        elif is_wheat and value >= 220:
            color = (255, 205, 42)
        elif is_wheat and value >= 182:
            color = (225, 170, 27)
        elif is_wheat:
            color = (166, 125, 17)
        elif value >= 175:
            color = (155, 164, 62)
        elif value >= 130:
            color = (137, 151, 58)
        else:
            color = (102, 118, 39)
        output_pixels.append((*color, 255))
    calibrated.putdata(output_pixels)
    return calibrated


def normalize(source: Path, destination: Path, color_count: int) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    hard_alpha = image.getchannel("A").point(lambda value: 255 if value >= 64 else 0)
    bbox = hard_alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{source} has no visible pixels")

    content = image.crop(bbox)
    content_alpha = hard_alpha.crop(bbox)
    canvas_side = round(max(content.size) / 0.90)
    canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
    offset = ((canvas_side - content.width) // 2, (canvas_side - content.height) // 2)
    canvas.alpha_composite(content, offset)
    alpha_canvas = Image.new("L", canvas.size, 0)
    alpha_canvas.paste(content_alpha, offset)

    tile = canvas.resize((60, 60), Image.Resampling.NEAREST)
    alpha = alpha_canvas.resize((60, 60), Image.Resampling.NEAREST)
    if destination.stem.startswith("wheat_"):
        limited = calibrate_wheat(tile, alpha)
        destination.parent.mkdir(parents=True, exist_ok=True)
        limited.save(destination, format="PNG", optimize=False)
        return limited
    fill = Image.new("RGB", tile.size, tile.convert("RGB").getpixel((30, 30)))
    fill.paste(tile.convert("RGB"), mask=alpha)
    limited = fill.quantize(
        colors=color_count,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    limited.putalpha(alpha)
    destination.parent.mkdir(parents=True, exist_ok=True)
    limited.save(destination, format="PNG", optimize=False)
    return limited


outputs: list[Image.Image] = []
for name, (filename, color_count) in SPECS.items():
    output = normalize(
        Path(f"tmp/imagegen/qingfeng_variants/{name}_source_alpha.png"),
        ROOT / filename,
        color_count,
    )
    outputs.append(output)
    visible = sum(1 for value in output.getchannel("A").get_flattened_data() if value > 0)
    corners = [output.getpixel(point)[3] for point in ((0, 0), (59, 0), (0, 59), (59, 59))]
    print(
        f"Wrote {ROOT / filename} size={output.size} "
        f"visible_ratio={visible / 3600:.3f} corner_alpha={corners}"
    )

preview = Image.new("RGBA", (1520, 520), (11, 28, 24, 255))
for index, output in enumerate(outputs):
    sprite = output.resize((480, 480), Image.Resampling.NEAREST)
    preview.alpha_composite(sprite, (20 + index * 500, 20))
PREVIEW.parent.mkdir(parents=True, exist_ok=True)
preview.convert("RGB").save(PREVIEW, format="PNG", optimize=False)
print(f"Wrote {PREVIEW}")
