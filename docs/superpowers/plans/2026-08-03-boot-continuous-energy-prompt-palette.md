# Boot Screen Continuous Energy, Prompt Perspective, and Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the Boot Screen idle presentation so gold energy only travels outward, the entry prompt shares the title perspective, and the title reads independently from its shadow.

**Architecture:** Keep the existing Boot Screen hierarchy and interaction unchanged. Modify the existing gold material to advect small-scale procedural distortion through the original pixels without a global phase seam, add one focused vertex shader for the prompt group, and update only the title palette parameters.

**Tech Stack:** Godot 4, GDScript, `canvas_item` shaders, GUT.

## Global Constraints

- Do not change click-to-enter behavior or Boot Screen layout beyond the approved prompt perspective.
- Do not add particle layers or duplicate gold-energy nodes.
- Gold-energy motion must not use a global phase band, scanning seam, brightness pulse, or reversing displacement.
- Use the approved steel-blue, navy, gold, and pale-blue title palette.
- Finish with real Godot runtime screenshots.

---

### Task 1: Lock the corrected contracts in tests

**Files:**
- Modify: `tests/unit/ui/test_boot_pressure_backdrop.gd`

- [ ] Assert that the gold shader uses continuously advected local noise without sine/cosine breathing or a phase-map scan.
- [ ] Assert the prompt has one continuous perspective material field.
- [ ] Assert the title uses the approved steel-blue palette and reduced shadow.

### Task 2: Implement one-way gold-energy transport

**Files:**
- Modify: `assets/shaders/canvas_boot_gold_energy.gdshader`
- Modify: `src/ui/components/boot_pressure_motion.gd`
- Modify: `src/ui/boot_screen.tscn`

- [ ] Replace phase-driven displacement and value pulsing with continuously advected, layered local noise.
- [ ] Keep hand motion restrained and make upper escape distortion travel upward without a broad scan front.
- [ ] Remove obsolete value-pulse parameters.

### Task 3: Implement prompt perspective and title palette

**Files:**
- Create: `assets/shaders/canvas_boot_prompt_perspective.gdshader`
- Modify: `src/ui/boot_screen.tscn`
- Modify: `src/ui/components/boot_title_controller.gd`

- [ ] Apply one shared group coordinate field to the label and both lines.
- [ ] Remove the nearly invisible container rotation.
- [ ] Apply the steel-blue title face, navy structure, gold cuts, pale-blue peak, and reduced shadow.

### Task 4: Verify

- [ ] Run Godot import.
- [ ] Run the focused Boot Screen tests.
- [ ] Run the Boot Screen screenshot probe and inspect multiple frames for direction, readability, and perspective.
