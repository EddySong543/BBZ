# Scene1 Bamboo Leaf Sway Design

## Goal

Give a small selection of leaves on `BambooLeft` and `BambooRight` a restrained
pixel-art sway while every bamboo culm, branch, root, and unselected leaf stays
on its authored source pixel.

## Selection

Each bamboo uses two motion groups. Each group contains two outer leaf blades,
for roughly four moving leaves per side. The masks stop before the petiole and
never include the vertical culms.

## Motion

The Scene2 blossom-tree inverse-rotation method is reduced to two mask channels.
Leaves rotate around authored hinge coordinates at 6 FPS, below 1.1 degrees,
with an 8.5-second cycle and different left/right phase offsets. A tiny
source-resolution underpaint covers only the hinge seam.

## Preservation

The new shader includes the current Scene1 night-foliage grade. The existing
node rectangles, texture filtering, parallax metadata, alpha, and scene order
remain unchanged. Far bamboo groves retain their existing static material.

## Verification

Tests check formal mask and underpaint paths, motion limits, and selected-pixel
budget. An isolated three-frame runtime probe verifies visible leaf changes and
zero change over unmasked bamboo pixels.
