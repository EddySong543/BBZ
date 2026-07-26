# Boot H01 Master Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and approve one high-resolution transparent H01 master keyframe with the final Boot Screen camera angle, chest-level energy gap, and vertically aligned hands.

**Architecture:** Generate one clean painterly source from the in-service H01 anime and pixel references, without energy, title, or background. Approve identity and anatomy before any layer extraction or Godot work so every later asset derives from one stable source.

**Tech Stack:** GPT Image 2 or an equivalent reference-image model, PNG with alpha, PixelLab only after source approval, Godot 4.7 import pipeline later.

## Global Constraints

- Use `assets/import/hero/h01.png` as the identity, costume, and painterly-style authority.
- Use `assets/sprites/heroes/h01/h01.png` only as the pixel silhouette and value-blocking reference.
- Keep the full body and both feet in frame on a transparent background.
- Keep the torso front-facing under a 10–15° low camera angle.
- Place one horizontal palm directly above the empty chest gap and one horizontal palm directly below it.
- Do not generate the gold sphere, energy lines, title, backdrop, weapon, or cast shadow.
- Do not reference an `assets/import` file from a production scene.

---

### Task 1: Generate the four master candidates

**Files:**
- Read: `assets/import/hero/h01.png`
- Read: `assets/sprites/heroes/h01/h01.png`
- Read: `design/references/boot_h01_pose_guide.png`
- Read: `design/boot-h01-master-prompt.md`
- Read: `design/boot-h01-midjourney-v81-prompt.md`
- Create externally, then place: `assets/import/boot/h01_master_candidates/boot_h01_master_candidate_01.png`
- Create externally, then place: `assets/import/boot/h01_master_candidates/boot_h01_master_candidate_02.png`
- Create externally, then place: `assets/import/boot/h01_master_candidates/boot_h01_master_candidate_03.png`
- Create externally, then place: `assets/import/boot/h01_master_candidates/boot_h01_master_candidate_04.png`

**Interfaces:**
- Consumes: two H01 reference images and the complete master prompt.
- Produces: four portrait PNG candidates with the same character and pose contract.

- [ ] **Step 1: Upload the references in the fixed order**

For GPT Image 2, upload `assets/import/hero/h01.png` first and
`assets/sprites/heroes/h01/h01.png` second.

For Midjourney V8.1, use `assets/import/hero/h01.png` and
`design/references/boot_h01_pose_guide.png` as Image Prompts, then use
`assets/sprites/heroes/h01/h01.png` as the Style Reference.

Do not attach `Zan_idle.png`, because its hand pose conflicts with the approved
vertical hand placement.

- [ ] **Step 2: Generate one high-quality batch**

Use a portrait canvas equivalent to 1024×1792, high quality, PNG, and four candidates in the same batch. Paste the complete prompt from `design/boot-h01-master-prompt.md`.

- [ ] **Step 3: Save candidates without editing**

Save the untouched outputs with the exact `candidate_01` through `candidate_04` names above. Preserve alpha and original resolution.

- [ ] **Step 4: Reject by pose before judging polish**

Reject any candidate where either hand is diagonal, the sphere gap is at the abdomen, the character is visibly holding something, the body is side-facing, fingers are malformed, or either foot is cropped.

### Task 2: Correct the strongest candidate

**Files:**
- Read: the strongest candidate from Task 1.
- Modify externally: the same candidate through conversational image editing.
- Create: `assets/import/boot/h01_master_review.png`

**Interfaces:**
- Consumes: one candidate with correct H01 identity and the fewest structural errors.
- Produces: one review PNG satisfying every pose and composition constraint.

- [ ] **Step 1: Choose by priority**

Use this priority order: vertical hand alignment, recognizable H01 costume, correct chest gap, correct low angle, correct anatomy, then surface polish.

- [ ] **Step 2: Apply only the necessary correction prompt**

Use the matching correction block from `design/boot-h01-master-prompt.md`. Instruct the model to keep all unmentioned pixels, costume details, framing, and character identity unchanged.

- [ ] **Step 3: Save the review image**

Save the corrected, untouched full-resolution PNG as `assets/import/boot/h01_master_review.png`.

- [ ] **Step 4: Inspect transparent edges**

View the image over both black and light gray. Reject halos, baked background pixels, cropped cloth, or opaque empty areas.

### Task 3: Archive the approved source

**Files:**
- Create directory: `assets/art_src/ui/boot/`
- Create: `assets/art_src/ui/boot/boot_h01_master_source.png`
- Do not create a production runtime asset yet.

**Interfaces:**
- Consumes: the approved `h01_master_review.png`.
- Produces: the single character source of truth for later layer extraction.

- [ ] **Step 1: Copy the approved pixels unchanged**

Copy the approved review PNG to `assets/art_src/ui/boot/boot_h01_master_source.png`. Do not resize, quantize, sharpen, or recolor it.

- [ ] **Step 2: Verify source identity**

Compare the archived source against `assets/import/hero/h01.png`. Confirm the asymmetric black hair, purple-black scarf, crossed chest straps, layered robe, gloves, and single visible violet eye remain recognizable.

- [ ] **Step 3: Verify pose contract**

Confirm the upper palm is horizontal directly above the chest gap, the lower palm is horizontal directly below it, both palms face each other, and neither hand touches an object.

- [ ] **Step 4: Stop before processing**

Do not run PixelLab, cut animation layers, create the gold sphere, or modify `boot_screen.gd` in this phase. Those actions begin only after the master source passes visual review.
