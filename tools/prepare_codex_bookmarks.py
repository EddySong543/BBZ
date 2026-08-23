"""Install the two approved codex bookmark masters without reconstructing them."""

from __future__ import annotations

import argparse
import hashlib
import shutil
from pathlib import Path

from PIL import Image


EXPECTED_SIZE = (150, 82)
EXPECTED_HASHES = {
    "idle": "A6448B554629E206DBB7FDC46359AC785A0DE6F6B4796A70D0986830AAE46AEC",
    "selected": "8C81DD81C768888A5AF60A779236247A836DA5D4B45A6EDE03FBCA76FB369B7A",
}
OUTPUT_NAMES = {
    "idle": "bookmark_chapter_idle.png",
    "selected": "bookmark_chapter_selected.png",
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _validate_master(path: Path, state: str) -> None:
    if not path.is_file():
        raise FileNotFoundError(path)
    actual_hash = _sha256(path)
    if actual_hash != EXPECTED_HASHES[state]:
        raise ValueError(
            f"{state} master hash changed: expected {EXPECTED_HASHES[state]}, got {actual_hash}"
        )
    with Image.open(path) as image:
        if image.mode != "RGBA" or image.size != EXPECTED_SIZE:
            raise ValueError(
                f"{state} master must be 150x82 RGBA, got {image.size} {image.mode}"
            )
        alpha_values = set(image.getchannel("A").get_flattened_data())
        if alpha_values != {0, 255}:
            raise ValueError(f"{state} master must use hard alpha, got {sorted(alpha_values)}")


def _install_exact(source: Path, destination: Path, state: str) -> None:
    _validate_master(source, state)
    shutil.copyfile(source, destination)
    if _sha256(destination) != EXPECTED_HASHES[state]:
        raise RuntimeError(f"{state} destination differs after copy: {destination}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Install the approved idle/selected bookmark masters exactly. "
            "Text, rarity stripes, scaling and shadows belong to Godot."
        )
    )
    parser.add_argument("--idle-source", type=Path, required=True)
    parser.add_argument("--selected-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    _install_exact(
        args.idle_source,
        args.output_dir / OUTPUT_NAMES["idle"],
        "idle",
    )
    _install_exact(
        args.selected_source,
        args.output_dir / OUTPUT_NAMES["selected"],
        "selected",
    )
    print(
        "CODEX_BOOKMARK_ASSETS_OK: two exact 150x82 RGBA masters installed; "
        "no rarity art, icons, resampling or baked shadows generated"
    )


if __name__ == "__main__":
    main()
