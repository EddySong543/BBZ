from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "tilesets" / "qingfeng_ricefield" / "golden_wave_ground_v1.png"
WAVE_DIR = ROOT / "assets" / "tilesets" / "qingfeng_ricefield" / "wheat_wave"
FRAMES_DIR = WAVE_DIR / "frames"
QA_DIR = ROOT / "design" / "previews" / "qingfeng_wheat_wave_sprite_qa_v1"
PREVIEW_GIF = QA_DIR / "wheat_wave_4x.gif"

# Eight coarse horizontal bands. Each number is a 2px source-image shift.
# The outside alpha/border pixels never move, so every frame remains the same
# approved rounded tile instead of gaining a separate animation rectangle.
SHIFT_PATTERNS = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 0, -1, -1, 0, 0],
    [0, 1, 2, 3, 2, 0, -1, -2],
    [2, 3, 2, 0, -2, -3, -2, 0],
    [1, 0, -1, -2, -1, 0, 1, 1],
    [0, 0, 0, 0, 0, 0, 0, 0],
]


def deform(source: Image.Image, pattern: list[int]) -> Image.Image:
    frame = source.copy()
    source_pixels = source.load()
    frame_pixels = frame.load()
    for y in range(4, 56):
        band = min(7, (y - 4) // 7)
        shift = pattern[band] * 2
        for x in range(4, 56):
            sample_x = min(55, max(4, x - shift))
            frame_pixels[x, y] = source_pixels[sample_x, y]
    return frame


def main() -> None:
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    preview_frames: list[Image.Image] = []
    for index, pattern in enumerate(SHIFT_PATTERNS):
        name = f"wheat_wave_{index:03d}.png"
        frame = deform(source, pattern)
        frame.save(FRAMES_DIR / name)
        preview_frames.append(frame.resize((240, 240), Image.Resampling.NEAREST))
    preview_frames[0].save(
        PREVIEW_GIF,
        save_all=True,
        append_images=preview_frames[1:],
        duration=[90, 110, 130, 130, 110, 90],
        loop=0,
        disposal=2,
    )
    print(f"saved {len(SHIFT_PATTERNS)} frames and 4x GIF preview to {WAVE_DIR}")


if __name__ == "__main__":
    main()
