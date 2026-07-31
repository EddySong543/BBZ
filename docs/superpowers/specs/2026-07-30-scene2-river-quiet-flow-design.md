# Scene2 River Quiet Flow Design

## Goal

Reduce Scene2 River's visible side-to-side oscillation so the water reads as
quietly flowing while retaining pixel-water motion, reflections, ripples, and
broken shoreline foam.

## Scope

- Change only `RiverMat` motion parameters in `src/ui/scenes/scene2.tscn`.
- Preserve the River shader, geometry, colors, reflections, light reception,
  focus quiet zones, and shoreline topology.
- Keep `anim_fps` at `6.0` so motion remains deliberately stepped without
  becoming visibly choppy.

## Parameters

- `slice_shift_px = 5.0`
- `slice_speed = 0.11`
- `breakup_strength = 0.20`
- `ripple_speed_px = 8.0`
- `shore_cluster_drift_px = 1.5`

The reflection bands provide low-amplitude breathing, while ripple rows retain
a slow directional current. Shore foam follows the calmer motion.

## Verification

- GUT locks the five values and confirms `anim_fps` remains `6.0`.
- A real Scene2 runtime probe captures multiple frames.
- Visual review confirms the river is not frozen and no other Scene2 layer or
  battle contract changes.
