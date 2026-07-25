# Scene2 P2 Motion Design

## Scope

P2 changes only Scene2 environmental motion. It preserves all authored node transforms, character placement, HUD, battle behavior, Scene1, P0 reflections, and P1 depth grading.

## Considered approaches

1. **Procedural petal shader:** cheapest asset pipeline, but it repeats one mathematical silhouette and does not satisfy the atlas requirement.
2. **Four-frame generated pixel atlas (selected):** deterministic 64×16 RGBA asset, four distinct 16×16 flutter poses, nearest filtering, and native Godot particle flipbook playback. It is reproducible, inspectable, and remains independent of battle logic.
3. **AnimatedSprite2D object pool:** offers per-petal control but adds scripts, pooling state, and many nodes for no visible benefit at the current particle counts.

## Selected design

- `scene2_petal_atlas.png` contains four 16×16 dusty-pink petal poses on true alpha.
- A shared `CanvasItemMaterial` reads the atlas as four horizontal particle frames.
- Far and near emitters retain separate physical depth behavior, but both run at fixed 12fps with interpolation and fractional delta disabled.
- Waterfall remains a restrained 5fps background motion; foreground river remains 8fps.
- River shoreline retains a stable dark contact band. Its bright continuous line is replaced by short, low-density clusters whose staggered lifetimes and slow lateral drift are quantized to the river's 8fps cadence.
- All three systems retain hard 3–4px visual grids and nearest filtering.

## Verification

- Tests protect relative cadence, atlas structure, true alpha, flipbook configuration, and foam density without pinning editor positions or sizes.
- Runtime validation uses one Scene2 battle screenshot plus the two-frame Scene2 probe to verify motion and seams.
- Scene1 receives a separate runtime regression screenshot.
- The full GUT suite remains the final automated gate.
