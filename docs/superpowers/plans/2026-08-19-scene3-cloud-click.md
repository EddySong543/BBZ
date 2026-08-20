# Scene3 Propagating Cloud Bounce Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace unreliable layer hit regions with a restrained front-to-back cloud bounce while preserving the left-click vertical-fish trigger.

**Architecture:** `Scene3CloudInteraction` accepts the whole cloud-area rectangle, then starts Front immediately, Mid after 0.06 seconds and Back after 0.12 seconds. Strength attenuates from 72% to 46% to 22%; the existing `cloud_disturbed` signal and vertical-fish trigger remain unchanged.

**Tech Stack:** Godot 4, typed GDScript, canvas-item shader, GUT, BattleScreen3 probe.

## Constraints

- Preserve all user-tuned Scene3 composition, base cloud motion, colors, lighting and automatic fish timing.
- Do not consume battle/UI input.
- Do not add independent puffs, rings, alpha holes, dawn gaps or scene-wide gusts.
- Trigger the vertical school probabilistically and repeatedly without overlapping active schools.

### Task 1: Lock the propagation contract

- [x] Assert one valid click reaches Front, Mid and Back in order with explicit delays.
- [x] Assert the shared cloud shader contains the press, shoulder and rebound profiles.
- [x] Assert the independent puff drawing path is absent.

### Task 2: Implement restrained propagation

- [x] Use the full cloud-area rectangle and remove per-layer hit-region selection.
- [x] Restore center depression, shoulder rise, quick rebound and light settle motion.
- [x] Set Front/Mid/Back strength to 72%, 46% and 22%, with 0.06/0.12-second propagation delays.
- [x] Remove the independent pixel-puff effect pool.

### Task 3: Preserve Fish Ascending Through Heaven

- [x] Keep the `cloud_disturbed` connection and all vertical-fish parameters unchanged.
- [x] Confirm a valid left click still reaches the fish easter egg while an invalid click does not.
- [x] Run both focused tests.

### Task 4: Verify the real composition

- [x] Run the full GUT suite and the image-free Scene3 runtime probe.
- [x] Check layer-exclusive shader parameters, input priority and the repeatable fast 2-3 fish gag from logs and assertions.
