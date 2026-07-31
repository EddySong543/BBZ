# Boot Char Asset Replacement Design

## Goal

Replace the current Boot Screen character with `assets/import/bootchar.png`
without changing the established layout, grading, or click-to-enter behavior.

## Design

- Copy the approved import asset over `assets/ui/boot/boot_char2.png` so the
  scene keeps its existing production path and resource identity.
- Keep the current `TextureRect` geometry and skin-grading masks because the
  replacement has the same 263 by 159 pixel canvas.
- Use the replacement image's native alpha channel instead of the legacy
  `#fefefe` background key, preventing near-white hair pixels from being
  removed.
- Verify the actual Boot Screen and its click transition with
  `tools/boot_shot_runner.tscn`.

## Success Criteria

- The runtime Boot Screen displays the new import asset with clean transparent
  edges and intact near-white hair pixels.
- Existing character placement and skin grading remain active.
- Clicking the Boot Screen still transitions to `res://src/ui/main_menu.tscn`.
