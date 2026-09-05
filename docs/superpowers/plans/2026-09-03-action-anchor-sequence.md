# Action Anchor Sequence Implementation Plan

> **For agentic workers:** Execute inline in the current task. Do not commit unless Eddy explicitly asks. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace left-aligned cross-player resolution with a shared action anchor so defense and attack always meet at beat zero without changing each player's submitted order.

**Architecture:** `BattleResolutionTimeline` retains immutable submitted sequences and builds a separate execution sequence padded with core-owned alignment waits. `ItemV2Resolution` consumes those columns unchanged, with one narrow pre-resolution exception that preserves H21's approved interruption contract at the shared action beat.

**Tech Stack:** Godot 4.7, statically typed GDScript, GUT, Markdown design truth sources.

## Global Constraints

- Exactly one `kind = "action"` step per submitted sequence.
- Main actions align at relative `beat = 0`; other steps retain their distance and order around that action.
- Alignment waits never alter submitted sequences, resources, item durability, or gameplay triggers.
- Do not modify H03 data, copy, or implementation until a redesign is approved.
- Preserve H21's existing interruption behavior without changing its cost or cap.

---

### Task 1: Lock the corrected scheduler contract

**Files:**
- Modify: `tests/unit/battle/v4/test_battle_resolution_timeline.gd`
- Modify: `tests/unit/battle/v4/test_item_v2_sequence.gd`

- [x] **Step 1: Add the four-beat anchor example and defense regression test.**
- [x] **Step 2: Add H03 post-action compatibility and H21 shared-anchor regression tests.**
- [x] **Step 3: Run both targets and verify they fail against left alignment.**

### Task 2: Build action-anchored execution columns

**Files:**
- Modify: `src/battle/battle_resolution_timeline.gd`

- [x] **Step 1: Keep submitted sequences immutable and build padded execution copies.**
- [x] **Step 2: Emit deterministic alignment waits and signed `beat` metadata.**
- [x] **Step 3: Ignore alignment-only tails when deciding whether an effect may insert a real delay.**
- [x] **Step 4: Run the timeline unit target to green.**

### Task 3: Preserve H21 at the shared action beat

**Files:**
- Modify: `src/battle/hero_skill.gd`
- Modify: `src/battle/skills/h21_diaohu.gd`
- Modify: `src/battle/item_v2_resolution.gd`

- [x] **Step 1: Add a default-false active preemption hook and enable it only for H21.**
- [x] **Step 2: Pay both actions first, then let H21 pull and cancel only an enemy base action before its effect resolves.**
- [x] **Step 3: Keep active-vs-active and active-vs-switch on the existing non-preemptive path.**
- [x] **Step 4: Run the item sequence and hero targets to green.**
- [x] **Step 5: Preserve switch → instant active → attack sub-order for H17/H22 and cover same-beat defeat plus H17-vs-H21.**

### Task 4: Update current truth sources and verify

**Files:**
- Modify: `docs/superpowers/specs/2026-08-28-item-sequence-interaction-design.md`
- Modify: `docs/superpowers/specs/2026-08-30-item-system-current-standard.md`
- Modify: `design/build-design-framework.md`
- Modify: `docs/reports/2026-08-31-item-design-complete-retrospective-and-handoff.md`

- [x] **Step 1: Replace current-rule references to left alignment with the action-anchor truth source.**
- [x] **Step 2: Remove the obsolete H03 sequence-shift design; the current H03 rule is recorded in the hero truth source.**
- [x] **Step 3: Run targeted sequence, item, hero, local-core, and compile tests through `tools/run_godot.ps1`.**
- [x] **Step 4: Run `git diff --check` and inspect only task-scoped diffs.**
