# Boot Character Layered Idle Design

## Goal

Replace the current boot character with the latest Photoshop-edited
`assets/import/bootchar.png`, preserve the user's saved visual size and
position exactly, split only motion-relevant silhouette pieces, and add a
subtle indefinitely looping pixel-art idle.

## Locked presentation

- Source canvas: `319x171`.
- Saved Control position: `(374.99994, 32.0)`.
- Saved Control size: `1052x636`.
- Saved uniform scale: `1.595`.
- The implementation may bake the root scale into layout size, but the
  runtime visual bounds must remain unchanged.
- The foreground hand, legs, face, and core costume remain static.
- Texture filtering remains nearest-neighbor.
- No blur, mesh warping, bone deformation, whole-character bob, or energy
  effect is included in this task.

## Layer model

All generated layer textures retain the full `319x171` canvas. This makes
their neutral positions identical and allows a byte/pixel reconstruction
check against the Photoshop source.

The static base removes only the exclusive outer pixels owned by moving
tips. Each moving layer also contains a small unremoved root overlap so that
one-pixel movement cannot reveal transparent seams.

Planned moving layers:

- `hair_left_tips`
- `hair_right_tips`
- `hair_front_tips`
- `fur_right_tips`
- `waist_cloth_tips`

The exact polygons are authored against the latest Photoshop source and
reviewed in an enlarged layer atlas before integration.

## Animation

- Loop length: `3.2` seconds.
- Movement is expressed in native source-pixel coordinates.
- Hair tips move by at most one source pixel horizontally or vertically.
- Fur tips follow the hair with a delayed, smaller one-pixel response.
- Waist cloth moves one source pixel in the opposite phase.
- Key changes use pixel-stepped/discrete interpolation.
- The first and final pose are identical.
- Frame zero must reconstruct the source image exactly.

## Scene structure

`boot_screen.tscn` instances a focused `boot_character_idle.tscn` component.
The component owns the native-resolution sprites, a single scale mapping
source pixels to the baked layout size, and the `AnimationPlayer`.

The boot screen continues to own the background, input gate, and transition
behavior. No boot interaction behavior changes.

## Acceptance

- Latest Photoshop face edits are visible.
- Neutral composite is pixel-identical to the latest source.
- Runtime visual bounds match the user's saved Scale version within one
  screen pixel.
- No transparent seams, duplicated tips, halos, or isolated pixels appear
  at animation extremes.
- The loop has no visible jump.
- Boot screenshot and transition-to-main-menu probes pass.
