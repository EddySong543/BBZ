#!/usr/bin/env python3
"""Build the two retained Scene2 mountain textures for an exact 2x pixel grid.

The imported source PNGs are immutable art masters. This tool creates Scene2-only
derivatives for MountainGate and MountainLeft. The newly imported FarMountain,
MidMountain, BlossomTree, and StoneBridge assets keep their own native/integer
scales and are prepared by ``prepare_scene2_environment_assets.gd`` instead.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "assets/scenes/scene2/scene2_px2_manifest.json"


@dataclass(frozen=True)
class PixelJob:
    source: str
    output: str
    width: int
    height: int
    palette_colors: int
    alpha_threshold: int = 96

    @property
    def size(self) -> tuple[int, int]:
        return self.width, self.height


JOBS: tuple[PixelJob, ...] = (
    PixelJob(
        "assets/scenes/scene2/scene2_mountain_gate.png",
        "assets/scenes/scene2/scene2_mountain_gate_px2.png",
        293,
        381,
        48,
    ),
    PixelJob(
        "assets/scenes/scene2/scene2_mountain_left.png",
        "assets/scenes/scene2/scene2_mountain_left_px2.png",
        264,
        420,
        48,
    ),
)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def harden_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    hard_alpha = rgba.getchannel("A").point(
        lambda alpha: 255 if alpha >= threshold else 0
    )
    rgba.putalpha(hard_alpha)
    transparent = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    return Image.composite(rgba, transparent, hard_alpha)


def normalize(job: PixelJob) -> Image.Image:
    source_path = REPO_ROOT / job.source
    if not source_path.is_file():
        raise FileNotFoundError(f"Missing source asset: {source_path}")

    with Image.open(source_path) as source:
        rgba = source.convert("RGBA")
        # Resize premultiplied RGBA so transparent pixels cannot produce dark or
        # white color fringes along the new hard pixel silhouette.
        resized = (
            rgba.convert("RGBa")
            .resize(job.size, Image.Resampling.BOX)
            .convert("RGBA")
        )

    hardened = harden_alpha(resized, job.alpha_threshold)
    quantized = hardened.quantize(
        colors=job.palette_colors,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    return harden_alpha(quantized, 128)


def manifest_entry(job: PixelJob, output_path: Path) -> dict[str, object]:
    entry = asdict(job)
    entry["logical_size"] = [job.width, job.height]
    entry["display_size"] = [job.width * 2, job.height * 2]
    entry["source_sha256"] = file_sha256(REPO_ROOT / job.source)
    entry["output_sha256"] = file_sha256(output_path)
    return entry


def generate() -> None:
    entries: list[dict[str, object]] = []
    for job in JOBS:
        output_path = REPO_ROOT / job.output
        output_path.parent.mkdir(parents=True, exist_ok=True)
        normalized = normalize(job)
        normalized.save(output_path, format="PNG", optimize=False, compress_level=9)
        entries.append(manifest_entry(job, output_path))
        print(
            f"generated {job.output}: {job.width}x{job.height}, "
            f"palette<={job.palette_colors}"
        )

    manifest = {
        "schema": "bbz.scene2-px2.v1",
        "logical_pixel_scale": 2,
        "filter": "nearest",
        "resampling": "premultiplied-box",
        "dither": "none",
        "assets": entries,
    }
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {MANIFEST_PATH.relative_to(REPO_ROOT)}")


def validate() -> None:
    failures: list[str] = []
    expected_manifest: list[dict[str, object]] = []

    for job in JOBS:
        output_path = REPO_ROOT / job.output
        if not output_path.is_file():
            failures.append(f"missing output: {job.output}")
            continue
        with Image.open(output_path) as output:
            rgba = output.convert("RGBA")
            if output.mode != "RGBA":
                failures.append(f"{job.output}: mode {output.mode}, expected RGBA")
            if output.size != job.size:
                failures.append(
                    f"{job.output}: size {output.size}, expected {job.size}"
                )
            alpha_values = set(rgba.getchannel("A").get_flattened_data())
            if not alpha_values.issubset({0, 255}):
                failures.append(
                    f"{job.output}: non-binary alpha values {sorted(alpha_values)[:8]}"
                )
            expected_pixels = normalize(job).tobytes()
            if rgba.tobytes() != expected_pixels:
                failures.append(f"{job.output}: pixels are stale or non-deterministic")
        expected_manifest.append(manifest_entry(job, output_path))

    if not MANIFEST_PATH.is_file():
        failures.append("missing scene2_px2_manifest.json")
    else:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        if manifest.get("schema") != "bbz.scene2-px2.v1":
            failures.append("manifest schema is not bbz.scene2-px2.v1")
        if manifest.get("logical_pixel_scale") != 2:
            failures.append("manifest logical_pixel_scale is not 2")
        if manifest.get("assets") != expected_manifest:
            failures.append("manifest asset entries do not match current sources/outputs")

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(f"validated {len(JOBS)} Scene2 px2 assets")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate existing outputs against current sources without writing",
    )
    args = parser.parse_args()
    if args.check:
        validate()
    else:
        generate()


if __name__ == "__main__":
    main()
