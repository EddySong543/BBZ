# Boot Screen H01 主图 Prompt

## 第一次出图怎么做

1. 优先使用支持多张参考图和对话修改的高质量图像模型。项目现行首选为 GPT Image 2；如果暂时无法使用，也可把同一 Prompt 交给 Rika AI、Midjourney 或其他参考图模型。
2. 按固定顺序上传两张图：
   - 图 1：`assets/import/hero/h01.png`
   - 图 2：`assets/sprites/heroes/h01/h01.png`
3. 选择竖版高质量输出，建议 1024×1792 或最接近的竖版比例。
4. 一次生成 4 张候选。
5. 这一轮不要上传 `assets/ui/icons/Zan_idle.png`，它的手势与本方案不一致。

## 主 Prompt

```text
Style anchor: high-detail full-body character key art for an oriental fantasy
game, painterly digital painting with visible confident brushwork, crisp
readable silhouette, and large clean color planes suitable for later HD-2D
pixel reduction. Heroic and restrained, not glossy, not photorealistic, not
chibi, no cartoon exaggeration. The character is rendered alone on a fully
transparent background as a PNG with alpha. No text anywhere.

Reference use is strict:

Image 1 is the identity and costume authority. Keep exactly the same H01
character: the same asymmetric messy black hair covering one eye, the same
purple-black high collar scarf, the same crossed chest straps, the same
layered dark-purple martial robe, wide sleeves, wrapped trousers, boots,
gloves, body proportions, and painterly design language.

Image 2 is only a secondary pixel-game reference. Take from it only H01's
compact readable silhouette, simplified value grouping, and dark-purple color
balance. Do not copy its tiny sprite proportions or its idle pose.

Subject and camera:

Create one full-body H01 standing upright and centered. The torso faces the
camera almost straight-on. The viewpoint is a restrained 10-to-15-degree low
angle with a mild wide-lens heroic feeling. Keep the head and hands natural:
no extreme foreshortening, no giant hands, no distorted face. The head tilts
slightly downward toward the empty space between the hands. Both feet and all
robe edges remain completely inside the frame.

Pose lock — this is the most important requirement:

H01 is gathering qi around an INVISIBLE sphere at the CENTER OF THE CHEST.
Leave one clean circular empty gap at chest level, about the width of the
character's head and a half.

The upper hand is placed HORIZONTALLY and DIRECTLY ABOVE that empty circular
gap. Its palm faces straight downward.

The lower hand is placed HORIZONTALLY and DIRECTLY BELOW that empty circular
gap. Its palm faces straight upward.

The two palms are vertically aligned on the same center line. They form a
clear top-and-bottom Tai Chi energy-gathering pose. They are NOT diagonal,
NOT side-by-side, NOT cupping from the left and right, NOT pushing toward the
viewer, and NOT lifting or holding an object.

Both arms curve naturally inward from the shoulders to support this pose, but
the palms do not touch the invisible sphere. Keep all fingers anatomically
correct, clearly separated, and readable. Preserve H01's gloves and hand-wrap
design while keeping the palm direction unmistakable.

Character adaptation for this Boot Screen:

Keep H01 recognizable, but reduce the number of hanging weapons, knives,
tools, and belt ornaments around the waist so the chest, hands, and empty
energy gap stay visually clean. Keep the scarf, crossed straps, layered robe,
wide sleeves, wrapped legs, and boots.

The face remains mostly in shadow beneath the asymmetric fringe. Show only one
subtle violet eye and a very thin restrained warm-gold rim light along parts
of the hair, cheek, upper gloves, and robe edges, as if a future chest-level
light source will illuminate the character. The dark-purple costume remains
visible as large controlled value shapes; do not crush the entire character
into a featureless black silhouette.

Movable-part discipline:

Give the front fringe, rear hair tips, one short scarf tail, sleeve edges, and
two or three large robe flaps clean separated silhouettes that can later be
cut into animation layers. Avoid wispy hair strands, tiny tassels, dense
jewelry, and excessive hanging clutter.

Asset exclusions:

Do not draw the gold sphere.
Do not draw any visible magic, energy streams, particles, halo, smoke, title,
letters, environment, floor, cast shadow, weapon, or backdrop.
Do not paint a black or gray rectangle behind the character.
Do not crop the head, hands, feet, scarf, sleeves, or robe.

Final self-check:

The result fails if the hands are diagonal.
The result fails if the upper and lower palms are not vertically aligned.
The result fails if the empty gap is at the abdomen instead of the chest.
The result fails if H01 appears to hold, lift, or touch a sphere.
The result fails if any energy effect, text, background, or weapon is visible.
The result fails if H01 is no longer recognizable from image 1.
The result fails if any finger is fused, missing, duplicated, or bent
unnaturally.

Output one full-body H01 only, centered on a portrait transparent canvas, with
generous transparent margin around the entire silhouette.
```

## 纠偏 Prompt：手掌仍然斜着

```text
Keep exactly this image, character identity, face, costume, camera, lighting,
framing, and transparent background. Change only the arms and hands.

Move the upper hand to the exact horizontal center directly above the empty
chest-level circular gap. Rotate it flat so the palm faces straight down.

Move the lower hand to the exact horizontal center directly below the same
gap. Rotate it flat so the palm faces straight up.

The two palms must share one vertical center line. They must not be diagonal,
left-and-right, cupped around the sides, or touching an object. Rebuild the
forearms naturally to connect the corrected hands to the shoulders. Preserve
H01's gloves and correct five-finger anatomy. Change nothing else.
```

## 纠偏 Prompt：模型画出了金球或特效

```text
Keep the character, corrected hands, face, costume, camera, framing, and every
other detail unchanged. Remove the sphere and remove every magic effect,
particle, glow cloud, energy ribbon, title, floor, and background. Restore a
clean fully transparent circular gap between the hands. Keep only the very
thin warm rim light already painted on H01's edges. Output PNG with alpha.
```

## 纠偏 Prompt：H01 腰部过于杂乱

```text
Keep H01's face, hair, scarf, crossed chest straps, robe, gloves, corrected
hands, pose, camera, lighting, and transparent background unchanged. Simplify
only the waist: remove hanging knives, tools, weapon handles, dense trinkets,
and most tiny cords. Retain one plain dark belt and two or three broad robe
layers. The chest-level empty energy gap and both hands must remain completely
clear. Change nothing else.
```

## 选图验收顺序

不要先挑“脸最好看”的图，按下面顺序检查：

1. 上掌正上、下掌正下，二者垂直对齐。
2. 球体位置是胸口空位，不是腹部。
3. H01 发型、围巾、交叉背带和深紫武服仍然可辨认。
4. 手指正确，双手没有接触或托举任何东西。
5. 轻仰视不过度，头和手没有夸张变形。
6. 全身、双脚和衣摆完整。
7. 背景真正透明，没有文字、球体和特效。

