# H11 Reference-Faithful Energy Bite Implementation Plan

> **For agentic workers:** Execute inline with GUT red-green verification. Do not create a worktree or commit unless Eddy explicitly requests it.

**Goal:** Rebuild h11's bite effect so individual teeth remain readable with tight spacing while the open and closed silhouettes stay faithful to `res/bite_open.png` and `res/bite.png`.

**Architecture:** Sample the approved source crops directly into the final 2px grid at high resolution; never reframe used bounds, mirror halves, union silhouettes, or procedurally redraw teeth. Preserve tooth shading as the energy carrier and use a coherent outline afterimage instead of random halo or powder.

**Tech Stack:** Godot 4.7.2, typed GDScript `Image`, PNG atlas, GUT.

## Global Constraints

- `res/bite_open.png` and `res/bite.png` are the only shape masters.
- Runtime copies must remain byte-identical to those masters.
- Open source crop remains `(0,0,982,455)` for the upper jaw and `(0,650,982,393)` for the lower jaw.
- No horizontal mirror, used-bound reframing, silhouette union, tooth redrawing, or random particles.
- Output remains eight `208×208` frames with visible `2×2` pixel blocks; 4px blocks were proven too coarse to preserve the approved tooth sequence.
- Significant solid-tooth components must remain separate; narrow intended gaps come directly from the master, with no artificial widening.
- Frame 7 is a coherent closed-jaw energy outline, not powder or detached fragments.

---

### Task 1: Reference and Tooth-Separation Contract

**Files:**
- Modify: `tests/unit/ui/test_h11_bite_fx.gd`
- Modify: `src/ui/components/h11_bite_fx.gd`

**Produces:** `audit_tooth_structure(image: Image) -> Dictionary` and source-transform guarantees.

- [ ] Add RED assertions for at least 12 significant tooth components, largest-component ratio below 0.25, maximum intentional horizontal gap no greater than 12px, and zero detached powder components in frame 7.
- [ ] Assert source UV locks and that mirror/reframe/redraw operations are disabled.
- [ ] Run the bite test and confirm it fails against the current gum-bed atlas.

### Task 2: Direct Reference Sampling

**Files:**
- Modify: `tools/generate_h11_bite_sheet.gd`
- Regenerate: `assets/effects/h11_bite/h11_bite_sheet.png`

**Produces:** Eight reference-faithful frames with tight preserved tooth gaps.

- [ ] Sample source crops directly to their fixed output rectangles using 2px block coverage and luminance; do not resize a merged binary mask.
- [ ] Quantize source shading into dark outline, blue-gray body, bright enamel, and white-blue energy accents.
- [ ] Move only complete upper/lower jaw images between open frames.
- [ ] Sample `bite.png` directly for the closed impact and build frame 7 by retaining a connected contour from that same closed shape.

### Task 3: Playback and Regression

**Files:**
- Modify: `src/ui/components/h11_bite_fx.gd`
- Test: `tests/unit/ui/test_h11_bite_fx.gd`
- Test: `tests/unit/ui/test_battle_resolution_bubble.gd`
- Test: `tests/unit/battle/v4/test_heroes_zodiac_v4.gd`

**Produces:** Reference-faithful visual playback with unchanged h11 damage timing.

- [ ] Generate twice and compare SHA-256.
- [ ] Import through `tools/run_godot.ps1`.
- [ ] Run bite, battle-order, hero-mechanic, and compile suites.
- [ ] Run `git diff --check` and report without committing.

### Task 4: Stage 1 Front-Facing Release Outline

**Files:**
- Modify: `tools/generate_h11_bite_sheet.gd`
- Modify: `src/ui/components/h11_bite_fx.gd`
- Test: `tests/unit/ui/test_h11_bite_fx.gd`

**Produces:** Frame 6 remains the `bite.png` impact, while frame 7 becomes a centered front-facing outline composed from the approved upper and lower `bite_open.png` crops.

- [ ] Add failing assertions for the release source and a maximum 2px upper/lower jaw center delta.
- [ ] Center the complete upper and lower reference masks independently without mirroring, scaling, or widening tooth gaps.
- [ ] Compose only frame 7 from the centered `bite_open.png` jaws at the existing closed gap; keep frames 0-6 unchanged.
- [ ] Regenerate twice, verify a stable SHA-256, and run the bite, battle-order, hero-mechanic, and compile suites.

### Task 5: Remove Release Outline and Apply Black Palette Filter

**Files:**
- Create: `assets/shaders/canvas_h11_bite_black_palette.gdshader`
- Modify: `tools/generate_h11_bite_sheet.gd`
- Modify: `src/ui/components/h11_bite_fx.gd`
- Test: `tests/unit/ui/test_h11_bite_fx.gd`

**Produces:** Frame 7 is fully transparent, and a local RGB-only palette shader makes the visible bite black-dominant without changing alpha, UVs, geometry, frame timing, or damage timing.

- [ ] Add failing assertions for a blank frame 7 and the four target shader colors.
- [ ] Replace the release mask with a transparent image and remove obsolete outline-alignment helpers.
- [ ] Apply a local CanvasItem palette-remap material to `PixelBiteFrames`; preserve sampled alpha exactly.
- [ ] Import the shader, regenerate twice, and run the bite, battle-order, hero-mechanic, and compile suites.

### Task 6: Stage 3 Anticipation Timing and Shadow-Energy Material

**Files:**
- Modify: `assets/shaders/canvas_h11_bite_black_palette.gdshader`
- Modify: `src/ui/components/h11_bite_fx.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/unit/ui/test_h11_bite_fx.gd`

**Produces:** A low-contrast black-violet shadow-energy palette without steel-blue specular cues, plus frame timing that emphasizes the fully formed pre-bite anticipation before a short snap and cleanup.

- [ ] Add failing assertions for the shadow-energy palette and `[0.08, 0.10, 0.25, 0.25, 0.18, 0.14]` close-frame weights.
- [ ] Replace graphite steel colors with `#08070B`, `#121018`, `#292331`, and `#74687F`; keep RGB-only mapping and exact alpha passthrough.
- [ ] Keep close duration at `0.22s`, set impact hold to `0.04s`, and shorten invisible release cleanup to `0.08s`.
- [ ] Import the shader and run the bite, battle-order, hero-mechanic, and compile suites.

### Task 7: Rebuild Stage 1 Static Pixel Frames

**Files:**
- Create: `tools/generate_h11_bite_stage1.gd`
- Create: `tools/h11_bite_stage1_lab.gd`
- Create: `tools/h11_bite_stage1_lab.tscn`
- Generate: `assets/effects/h11_bite/h11_bite_stage1_sheet.png`
- Test: `tests/unit/ui/test_h11_bite_stage1_lab.gd`

**Produces:** Two isolated acceptance frames—fully open and closed—built on a 52x52 logical grid, enlarged to 208x208 with exact 4x4 clusters, without replacing the formal battle animation.

- [ ] Add failing tests for exact 4x4 clusters, three-color shadow-energy palette, 2-6% energy pixels, at least 12 separated teeth, and an F6-runnable isolated lab.
- [ ] Extract the approved open and closed source-derived masks, project them to 52x52, and protect one-cell tooth seams before colorization.
- [ ] Bake `#08070B`, `#17131D`, and `#5B4968` directly into the prototype sheet; use internal broken energy clusters only, with no bright contour bands.
- [ ] Create the isolated F6 lab and verify deterministic generation, imports, pixel contracts, and unchanged formal h11 battle tests.
