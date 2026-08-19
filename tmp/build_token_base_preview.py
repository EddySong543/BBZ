from pathlib import Path

from PIL import Image


ROOT = Path(
    r"D:\Game\BoBoZan\Claude-Code-Game-Studios-cn-localization"
    r"\design\references\qingfeng_ricefield"
)
def build(palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    image = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(32):
        for x in range(32):
            edge_distance = min(x, y, 31 - x, 31 - y)
            color_class = 0 if edge_distance < 2 else (1 if edge_distance < 3 else 2)
            pixels[x + 4, y + 4] = palette[color_class] + (255,)
    return image


neutral = build(((18, 22, 28), (205, 211, 216), (112, 118, 122)))
neutral.resize((480, 480), Image.Resampling.NEAREST).save(
    ROOT / "token_base_neutral_preview_v1.png"
)

palettes = [
    ((12, 20, 38), (55, 220, 240), (16, 96, 166)),
    ((55, 31, 10), (255, 220, 92), (207, 135, 24)),
    ((32, 38, 14), (226, 205, 107), (105, 113, 48)),
    ((46, 14, 19), (255, 137, 112), (164, 53, 50)),
]
sheet = Image.new("RGBA", (1024, 1024), (14, 29, 24, 255))
for palette, position in zip(palettes, [(32, 32), (528, 32), (32, 528), (528, 528)]):
    tile = build(palette).resize((464, 464), Image.Resampling.NEAREST)
    sheet.alpha_composite(tile, position)
sheet.save(ROOT / "token_base_palette_preview_v1.png")
