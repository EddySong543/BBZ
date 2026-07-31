# Boot Char Asset Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute this single task inline
> and verify the runtime result before reporting completion. Steps use checkbox
> (`- [ ]`) syntax for tracking.

**Goal:** Connect the new `assets/import/bootchar.png` to the production Boot Screen.

**Architecture:** Preserve the existing scene resource path by replacing only
the production PNG. Update the existing grading shader to trust the new
texture's native alpha channel.

**Tech Stack:** Godot 4.7, PNG, Godot canvas-item shader

## Global Constraints

- Preserve the current Boot Screen layout and click-to-enter behavior.
- Keep lossless, no-mipmap pixel-art import settings.
- Do not modify unrelated working-tree changes.

---

### Task 1: Replace and verify the Boot character

**Files:**
- Replace: `assets/ui/boot/boot_char2.png`
- Modify: `assets/shaders/canvas_boot_skin_grade.gdshader`
- Test: `tools/boot_shot_runner.tscn`

**Interfaces:**
- Consumes: `assets/import/bootchar.png`, a 263 by 159 PNG with native alpha.
- Produces: The existing `res://assets/ui/boot/boot_char2.png` resource with
  unchanged scene references.

- [x] **Step 1: Validate the source and target image dimensions**

Run a pixel metadata check and require both images to be 263 by 159.

- [x] **Step 2: Replace the production PNG**

Copy `assets/import/bootchar.png` over `assets/ui/boot/boot_char2.png` without
changing the `.import` resource identity.

- [x] **Step 3: Switch the shader to native alpha**

Remove the legacy `#fefefe` background-key calculation and output:

```glsl
COLOR = vec4(graded, tex.a);
```

- [x] **Step 4: Run the Boot Screen probe**

Run:

```powershell
& .\tools\run_godot.ps1 -Mode Probe -Target 'res://tools/boot_shot_runner.tscn'
```

Expected output includes:

```text
BOOT_CHAR2_PROBE_OK
BOOT_CHAR2_INPUT_OK: res://src/ui/main_menu.tscn
```

- [x] **Step 5: Inspect the generated runtime screenshot**

Open `D:\Game\BoBoZan\boot_char2_preview.png` and verify the replacement,
transparent perimeter, hair highlights, placement, and skin grading.
