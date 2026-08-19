from pathlib import Path

from PIL import Image


SOURCE = Path("tmp/imagegen/qingfeng_dirt/dirt_source_alpha.png")
DESTINATION = Path(
    "assets/tilesets/qingfeng_ricefield/candidates/dirt_scheme1_v1.png"
)
PREVIEW = Path("tmp/imagegen/qingfeng_dirt/dirt_scheme1_v1_preview.png")
FAMILY_PREVIEW = Path("D:/Game/BoBoZan/_probe_output/qingfeng_four_tiles_preview.png")


image = Image.open(SOURCE).convert("RGBA")
crop_side = min(image.size) * 1152 // 1254
left = (image.width - crop_side) // 2
top = (image.height - crop_side) // 2
square = image.crop((left, top, left + crop_side, top + crop_side))
tile = square.resize((60, 60), Image.Resampling.NEAREST)

alpha = tile.getchannel("A").point(lambda value: 255 if value >= 64 else 0)
quantize_base = Image.new("RGB", tile.size, (196, 126, 34))
quantize_base.paste(tile.convert("RGB"), mask=alpha)
limited = quantize_base.quantize(
    colors=8,
    method=Image.Quantize.MEDIANCUT,
    dither=Image.Dither.NONE,
).convert("RGBA")
limited.putalpha(alpha)

DESTINATION.parent.mkdir(parents=True, exist_ok=True)
limited.save(DESTINATION, format="PNG", optimize=False)
limited.resize((600, 600), Image.Resampling.NEAREST).save(
    PREVIEW, format="PNG", optimize=False
)

family_paths = [
    Path("assets/tilesets/qingfeng_ricefield/candidates/grass_scheme1_v1.png"),
    Path("assets/tilesets/qingfeng_ricefield/candidates/stone_scheme1_v1.png"),
    Path("assets/tilesets/qingfeng_ricefield/candidates/wheat_scheme1_v2.png"),
    DESTINATION,
]
family_preview = Image.new("RGBA", (1020, 1020), (11, 28, 24, 255))
for index, path in enumerate(family_paths):
    sprite = Image.open(path).convert("RGBA").resize(
        (480, 480), Image.Resampling.NEAREST
    )
    x = 20 + (index % 2) * 500
    y = 20 + (index // 2) * 500
    family_preview.alpha_composite(sprite, (x, y))
FAMILY_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
family_preview.convert("RGB").save(FAMILY_PREVIEW, format="PNG", optimize=False)

visible = sum(1 for value in alpha.getdata() if value > 0)
colors = len(set(limited.getdata()))
corners = [limited.getpixel(point)[3] for point in ((0, 0), (59, 0), (0, 59), (59, 59))]
print(
    f"Wrote {DESTINATION} size={limited.size} colors={colors} "
    f"visible_ratio={visible / 3600:.3f} corner_alpha={corners}"
)
print(f"Wrote {PREVIEW}")
print(f"Wrote {FAMILY_PREVIEW}")
