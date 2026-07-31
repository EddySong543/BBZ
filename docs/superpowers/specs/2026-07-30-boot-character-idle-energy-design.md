# Boot Character Idle and Rear-Hand Energy Design

## Scope

This pass changes only the existing boot character idle and adds a
procedural energy star to the character's rear hand. The boot background
remains unchanged until the separate bright-background discussion.

## Idle

- Preserve the character root position, visible size, source textures, and
  neutral reconstruction.
- Animate the three hair-tip layers and the full right hanging waist cloth.
- Outer hair displacement is capped at `0.38` source pixels, approximately
  two screen pixels at the current rig scale.
- Front hair displacement is capped at `0.19` source pixels.
- Remove all front-arm fur and full-waist translation.
- Rotate the isolated waist-cloth assembly around its belt root at `(183, 91)`
  by no more than `0.032` radians, keeping the root visually attached.
- Use a `4.8` second loop with smooth interpolation and identical first and
  final poses.

## Rear-hand energy

- Attach the effect to a dedicated rear-hand anchor at source coordinate
  `(116, 47)`, centered on the palm.
- Render the effect procedurally with canvas shaders; no raster VFX asset is
  required.
- Split the effect into a low-intensity glow behind the character and a
  crisp four-point star above the character.
- Bake the user-authored `1.37` anchor Scale into the glow and star rectangle
  sizes while preserving position `(112.68, 47.125)`.
- Shape each ray as a gently curved, mid-swell tapered lance instead of a
  straight line.
- Render the core as a circular white-gold orb with a separated faint ring.
- Set the core radius to `0.18` while keeping the static ring at radius
  `0.25`, so the orb grows without changing the surrounding star geometry.
- Emit two additional rings from the core per `4.8` second loop; each ring
  expands and fades before the next pulse starts.
- Birth each release ring inside the static core halo with zero opacity,
  ease it into view before significant travel, and return to zero opacity
  before its phase resets. The ring must never pop into existence or move
  inward.
- Keep all four ray lengths fixed. Move a brightness band from the core to
  each ray tip so the energy only reads as travelling outward, without any
  visual contraction or star rotation.
- Use a warm white core and restrained gold rays.
- Pulse slowly without random flashes, particles, rotation, or camera
  movement.
- Keep all values exposed in the Godot Inspector.

## Protected behavior

- The foreground hand, body, face, and costume remain static.
- Boot input gating and transition to `main_menu.tscn` remain unchanged.
- The character remains nearest-neighbor and pixel-crisp.
- The future background will be bright; no background implementation is
  included in this pass.

## Approved future background

- Use the "morning paper martial realm" direction.
- Keep the left side calm for future title composition.
- Use warm ivory and pale cyan as the bright base, with a desaturated
  blue-gray ink silhouette behind the white-haired character for contrast.
- Build depth from a paper-sky layer, distant ink landscape, thin dark stone
  footing, restrained haze, and sparse golden energy motes.
- Reuse the mature scene mouse-parallax behavior with only a few pixels of
  movement and no camera motion.

## Acceptance

- Hair motion is visibly smaller and does not resemble shaking.
- Front-arm fur remains static, and the full isolated waist cloth moves as
  one attached garment piece.
- The energy point is centered on the rear hand, not the foreground palm.
- The star reads as a four-point cross with a subtle glow.
- The first and last idle frames are pixel-identical.
- Runtime screenshot, animation-frame, and click-transition probes pass.
