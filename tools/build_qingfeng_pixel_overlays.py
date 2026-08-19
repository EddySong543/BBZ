from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OVERLAY_DIR = ROOT / "assets" / "tilesets" / "qingfeng_ricefield" / "overlays"
PREVIEW_DIR = ROOT / "design" / "previews"
GRASS_PATH = ROOT / "assets" / "tilesets" / "qingfeng_ricefield" / "grass_ref37_ref39_plain_v1.png"
DIRT_PATH = ROOT / "assets" / "tilesets" / "qingfeng_ricefield" / "dirt_ref37_ref39_plain_v1.png"
CANVAS_SIZE = 60
DETAIL_PIXEL = 2


def new_sprite() -> Image.Image:
    return Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))


def detail_block(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    color: tuple[int, int, int, int],
) -> None:
    draw.rectangle((x, y, x + DETAIL_PIXEL - 1, y + DETAIL_PIXEL - 1), fill=color)


def detail_blocks(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[int, int]],
    color: tuple[int, int, int, int],
) -> None:
    for x, y in points:
        detail_block(draw, x, y, color)


def paint_map(
    draw: ImageDraw.ImageDraw,
    origin: tuple[int, int],
    rows: list[str],
    palette: dict[str, tuple[int, int, int, int]],
) -> None:
    ox, oy = origin
    for row_index, row in enumerate(rows):
        for column_index, key in enumerate(row):
            if key == ".":
                continue
            detail_block(
                draw,
                ox + column_index * DETAIL_PIXEL,
                oy + row_index * DETAIL_PIXEL,
                palette[key],
            )


def flower(petal: tuple[int, int, int, int], center: tuple[int, int, int, int]) -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    # The approved preview's flowers are tiny repeatable crosses.  Each visible
    # square is one native 2x2 logical pixel, so several flowers can share a
    # 60px tile without becoming the tile's main object.
    detail_blocks(draw, [(28, 26), (26, 28), (30, 28), (28, 30)], petal)
    detail_block(draw, 28, 28, center)
    return image


def short_grass() -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    paint_map(draw, (22, 24), [
        "...d....",
        "..dm.d..",
        ".lmd.dm.",
        ".dmdld..",
        "dmddddm.",
        "ddddddd.",
        ".ddddd..",
    ], {
        "d": (36, 78, 34, 255),
        "m": (54, 104, 40, 255),
        "l": (84, 130, 49, 255),
    })
    return image


def clover() -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    palette = {
        "d": (42, 72, 31, 255),
        "m": (94, 136, 55, 255),
        "l": (130, 164, 69, 255),
        "h": (150, 181, 78, 255),
    }
    # Trace the approved bottom-middle preview: three complete rounded leaves,
    # a dark shared centre and a short stem.  The 20x18 footprint deliberately
    # leaves enough room for other overlays on the same cell.
    detail_blocks(draw, [(30, 26), (30, 28), (30, 30), (30, 32), (30, 34), (30, 36), (30, 38)], palette["d"])
    leaf = [".dd.", "dmmd", "dmld", ".dd."]
    paint_map(draw, (26, 20), leaf, palette)
    paint_map(draw, (22, 28), leaf, palette)
    paint_map(draw, (32, 28), leaf, palette)
    detail_blocks(draw, [(28, 28), (30, 28)], palette["d"])
    return image


def stone_chips() -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    palette = {
        "d": (92, 95, 69, 255),
        "m": (151, 149, 115, 255),
        "l": (193, 187, 145, 255),
        "h": (224, 216, 174, 255),
    }
    stone = ["..d..", ".dmh.", "dmhld", ".ddd."]
    paint_map(draw, (24, 22), stone, palette)
    paint_map(draw, (34, 30), ["..d..", ".dml.", "dlhmd", ".ddd."], palette)
    paint_map(draw, (20, 36), ["..d..", ".dmh.", "dmlmd", ".ddd."], palette)
    return image


def straw_fragments() -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    shadow = (132, 87, 24, 255)
    gold = (220, 157, 38, 255)
    light = (244, 190, 62, 255)
    # Four separated fragments and their approved directions/layout.
    detail_blocks(draw, [(22, 24), (24, 26), (26, 26), (28, 28)], gold)
    detail_blocks(draw, [(22, 24)], light)
    detail_blocks(draw, [(28, 28)], shadow)
    detail_blocks(draw, [(34, 22), (36, 22), (38, 20)], gold)
    detail_blocks(draw, [(34, 22)], light)
    detail_blocks(draw, [(38, 20)], shadow)
    detail_blocks(draw, [(38, 28), (36, 30), (34, 32)], gold)
    detail_blocks(draw, [(38, 28)], light)
    detail_blocks(draw, [(34, 32)], shadow)
    detail_blocks(draw, [(26, 36), (28, 38), (30, 38)], gold)
    detail_blocks(draw, [(26, 36)], light)
    detail_blocks(draw, [(30, 38)], shadow)
    return image


def green_leaves() -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    palette = {
        "d": (33, 76, 34, 255),
        "m": (62, 128, 48, 255),
        "l": (99, 164, 63, 255),
        "h": (143, 194, 77, 255),
    }
    # Two fallen leaves from the approved preview, recoloured green as
    # requested.  Jagged silhouettes replace the rejected rectangular blobs.
    paint_map(draw, (22, 22), [
        "...dd", ".ddmd", "dmhmd", ".dddd",
    ], palette)
    paint_map(draw, (32, 32), [
        "dd...", "dmddd", "dmlmd", ".ddd.",
    ], palette)
    return image


def dirt_crack() -> Image.Image:
    image = new_sprite()
    draw = ImageDraw.Draw(image)
    deep = (76, 45, 22, 255)
    edge = (105, 61, 25, 255)
    main = [(26, 18), (26, 20), (28, 22), (28, 24), (30, 26), (30, 28),
            (32, 30), (32, 32), (34, 34), (34, 36), (36, 38), (36, 40)]
    detail_blocks(draw, main, deep)
    detail_blocks(draw, [(28, 24), (26, 26), (24, 28), (22, 30), (20, 32)], deep)
    detail_blocks(draw, [(32, 30), (34, 30), (36, 30), (38, 32), (40, 32)], deep)
    detail_blocks(draw, [(28, 22), (26, 22), (24, 20), (34, 36), (32, 38), (30, 40)], edge)
    return image


def save_sprite(name: str, image: Image.Image) -> Path:
    path = OVERLAY_DIR / name
    image.save(path)
    return path


def composite_panel(base: Image.Image, overlay: Image.Image) -> Image.Image:
    panel = base.copy().convert("RGBA")
    panel.alpha_composite(overlay)
    return panel.resize((240, 240), Image.Resampling.NEAREST)


def checker_panel(overlay: Image.Image, dark: bool) -> Image.Image:
    colors = ((31, 36, 31, 255), (58, 65, 56, 255)) if dark else ((218, 220, 207, 255), (245, 245, 232, 255))
    base = Image.new("RGBA", (60, 60), colors[0])
    draw = ImageDraw.Draw(base)
    for y in range(0, 60, 8):
        for x in range(0, 60, 8):
            if (x // 8 + y // 8) % 2:
                draw.rectangle((x, y, x + 7, y + 7), fill=colors[1])
    base.alpha_composite(overlay)
    return base.resize((240, 240), Image.Resampling.NEAREST)


def make_previews(plants: list[Image.Image], details: list[Image.Image]) -> None:
    grass = Image.open(GRASS_PATH).convert("RGBA")
    dirt = Image.open(DIRT_PATH).convert("RGBA")

    plant_preview = Image.new("RGBA", (240 * len(plants), 240), (0, 0, 0, 255))
    for index, sprite in enumerate(plants):
        plant_preview.alpha_composite(composite_panel(grass, sprite), (index * 240, 0))
    plant_preview.save(PREVIEW_DIR / "qingfeng_small_overlays_formal_preview_v4.png")

    detail_preview = Image.new("RGBA", (720, 480), (0, 0, 0, 255))
    for index, sprite in enumerate(details):
        base = grass if index < 3 else dirt
        detail_preview.alpha_composite(composite_panel(base, sprite), ((index % 3) * 240, (index // 3) * 240))
    detail_preview.save(PREVIEW_DIR / "qingfeng_ground_details_formal_preview_v4.png")

    qa = Image.new("RGBA", (240 * len(plants), 720), (0, 0, 0, 255))
    for index, sprite in enumerate(plants):
        qa.alpha_composite(composite_panel(grass, sprite), (index * 240, 0))
        qa.alpha_composite(checker_panel(sprite, False), (index * 240, 240))
        qa.alpha_composite(checker_panel(sprite, True), (index * 240, 480))
    qa.save(PREVIEW_DIR / "qingfeng_small_overlays_alpha_qa_v4.png")


def main() -> None:
    OVERLAY_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    plant_names = [
        "overlay_flower_white_v1.png",
        "overlay_flower_yellow_v1.png",
        "overlay_flower_pink_v1.png",
        "overlay_short_grass_v1.png",
        "overlay_clover_v1.png",
    ]

    detail_names = [
        "overlay_stone_chips_pale_v1.png",
        "overlay_straw_fragments_v1.png",
        "overlay_green_leaves_v1.png",
        "overlay_dirt_crack_v1.png",
    ]
    plants = [Image.open(OVERLAY_DIR / name).convert("RGBA") for name in plant_names]
    details = [Image.open(OVERLAY_DIR / name).convert("RGBA") for name in detail_names]
    make_previews(plants, details)
    print("preserved 5 plant overlays and 4 approved ground details")


if __name__ == "__main__":
    main()
