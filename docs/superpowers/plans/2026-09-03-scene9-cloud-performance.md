# Scene9 Cloud Performance Implementation Plan

**Goal:** Remove Scene9's dominant procedural-cloud CPU stalls without changing the accepted composition.

**Architecture:** Keep the work inside Scene9-specific scripts, shaders, scene parameters, tests, and image-free tools. Each cloud reconstructs the cleaned blueprint once, then a scene-local GPU material performs the live remap and ripple while CPU rendering remains test-only.

**Tech Stack:** Godot 4.7, typed GDScript, CanvasItem shaders, GUT, `tools/run_godot.ps1`.

## Preserved constraints

- Preserve Scene9 node transforms, draw order, palette, parallax metadata, and manual composition.
- Do not edit shared Battle/UI scripts, shared scene behavior, or Scene1-8 resources.
- Keep nearest-neighbor pixel sampling and hard-alpha source artwork.
- Run only image-free Godot tests and tools.

## Completed work

- The two distant cloud banks use isolated GPU materials and share immutable base-pixel and metadata textures.
- Live animation updates shader uniforms without recurring CPU image rebuilds or texture uploads.
- Scene9-only foreground and grass wind meshes were reduced to at most 10,000 animated quads while preserving their transforms and displacement contracts.
- `tools/scene9_performance_audit.gd` distinguishes test-only CPU rendering from the live GPU path and reports setup cost, upload rate, and mesh inventory.
- Scene9 interaction, environment, framework, palette, interlock, battle-screen compile, and performance checks cover the retained cloud implementation.
