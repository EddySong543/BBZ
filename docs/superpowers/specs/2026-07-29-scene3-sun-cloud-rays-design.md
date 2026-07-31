# Scene3 Hidden-Sun Cloud Rays Design

## Goal

Create intermittent, broad morning sunlight that emerges through the lower
cloud sea and clearly shares the direction of the replacement dawn sun.

## Composition

- Keep `SunRayField` above the distant mountains and below `CloudSeaBack`.
- Place one hidden direction source below the cloud sea near the valley center.
- Prepare `assets/import/sun.png` into a cropped true-alpha formal asset.
- Place the replacement `DawnSun` after `SunRayField` and before
  `CloudSeaBack`, with its lower half fading into the cloud sea.
- Reuse the pale Scene2 distant range as three vertically offset layers. Keep
  the original layer farthest and increase contrast, opacity, and parallax
  toward the two nearer copies.
- Arrange six candidate shafts along the source's upper semicircle: left shafts
  lean left, central shafts rise upward, and right shafts lean right.
- Each shaft begins inside the lower cloud bank and expands as it rises.
- The shared direction must read as sunlight without drawing a solid radial fan,
  source disc, or halo.

## Motion

The shafts reuse `CloudSeaMid` roll and billow speed/phase values. Each shaft
uses a distinct phase and threshold, allowing zero, one, or several shafts to
appear at once. Opacity and width breathe slowly; direction stays stable and
source drift remains subtle.

## Visual Treatment

- Use broad shafts roughly two to three times the previous width.
- Build each shaft from a soft inner body and a wider, faint outer bloom.
- Keep the warmest color near the hidden cloud opening and fade toward a
  desaturated gray-gold higher in the sky.
- Fade the upper extent gradually and keep every root behind the cloud sea.
- Avoid narrow rectangular columns, hard edges, and searchlight-like contrast.
- Grade the imported orange sun toward restrained warm gold, preserving dawn
  warmth without returning to saturated orange or the rejected gray-white.
- Strongly desaturate and haze `RightFarMountain` so its authored deep blue
  matches the other distant mountains.

## Verification

- Shader defines one `hidden_sun_center` and semicircular direction logic.
- At least six candidate shafts use distinct cloud-gap phases.
- Material exposes broad inner width and outer feather controls.
- Runtime frames at separated timestamps show changing multi-shaft coverage.
- Scene3 contains one graded `DawnSun` using the new cropped round sun asset.
- Three distant range layers progress from pale/slow to darker/faster.
- `RightFarMountain` uses a decisive neutral atmospheric grade.
- Full GUT and Scene3 battle probes pass.
