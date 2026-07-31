# Boot Remaster Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Execute one numbered task at a time in the current BBZ task. Every task ends with a Godot runtime check.

**Goal:** Move the Boot Screen remaster from editable motion draft to the production entry without losing the approved composition or input rules.

**Architecture:** Continue using the separate static and animation previews through Tasks 1–5. Only Task 6 is allowed to replace the production Boot Screen; Task 7 performs regression verification and release closeout.

**Tech Stack:** Godot 4.7.1, GDScript, Control nodes, canvas drawing/shaders, GUT, `tools/run_godot.ps1`.

## Global Constraints

- The reveal blocks input until the camera settles.
- The final frame has no camera motion and waits indefinitely for player input.
- The approved giant moon, pixel cloud sea, title, H01 pose, orb position, and balanced ribbon layout remain the visual baseline.
- Godot runs only through `tools/run_godot.ps1`.
- No commit or push without Eddy explicitly requesting it.

---

### Task 1: Motion draft revision — current task

- Replace ribbon opacity fade with a geometry-mask reveal that grows from the orb.
- Shorten the reveal from `5.8` to `4.0` seconds.
- Keep ribbons in restrained slow growth until `2.05`, then lengthen them together with the rapid pullback.
- Keep composition zoom at or above `1.0` so the pullback never exposes black edges.
- Add anticipation, rapid pullback, and a controlled settle curve.
- Expose timing and camera values in the animation-preview root Inspector.
- Verify a six-frame contact sheet and one real-time playthrough.

### Task 2: Pullback environment and title entrances — current task

- Completed: bring the giant moon in with scale and upward spatial motion synchronized to the pullback; do not use a simple opacity fade.
- Completed: bring the cloud sea in with upward entry and layered lateral motion, using Scene2 lower-cloud continuous banks.
- Completed: bring the three title glyphs in with staggered directional motion and scale settle; do not use a simple opacity fade.
- Keep all three entrances subordinate to the character and energy orb, and settle them before `4.0`.
- Verify the full motion at runtime before starting idle effects.

### Task 3: Final-frame idle effects

- Keep camera scale and position fixed after `4.0` seconds.
- Add restrained hair-tip movement without shifting the head or face.
- Keep ribbon flow, orb light, and cloud drift on separate low-speed loops.
- Verify that no idle layer jitters, changes layout, or blocks input.

### Task 4: Production visual polish

- Completed for background structure: replace the draft block cloudscape with Scene1 night-sky/moon treatment and Scene2 lower-cloud layers.
- Finalize cloud palette, ribbon color, glow strength, title contrast, and character lighting after formal asset review.
- Verify at 1920×1080 and at the project stretch target without changing composition.

### Task 5: Boot interaction and transition

- Keep all mouse, keyboard, and gamepad entry input locked during `0.0–4.0`.
- After `4.0`, show the approved entry hint and accept player input.
- Connect the existing Boot-to-next-screen transition and add the approved audio cues.
- Verify repeated entry input cannot trigger duplicate transitions.

### Task 6: Draft-to-production promotion

**This is the exact task where the remaster stops being a draft and becomes the formal Boot Screen.**

Promotion may start only after Eddy approves all four of these:

1. The complete `4.0`-second reveal rhythm.
2. The indefinite final-frame idle loop.
3. The final visual polish at runtime.
4. The input and transition behavior.

During promotion:

- Preserve the old Boot scene as a recoverable fallback scene.
- Replace the production Boot visual composition instead of overlaying the old one.
- Keep `project.godot` pointing to the production Boot entry.
- Remove draft-only runner dependencies from the production path.

### Task 7: Production regression and closeout

- Run the focused Boot tests and the full GUT suite.
- Run the production Boot through a windowed screenshot/input probe.
- Check black opening, reveal timing, final idle, input lock, one-shot entry transition, and transparent edges.
- Report remaining draft tools separately.
- Commit and push only when Eddy explicitly requests `commit+push`.
