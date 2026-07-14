# 现役 UI 小件 prompt 存档（2026-07-14）

> **用途**：未完成落位的小件出图 prompt 快照——防 session 切换丢失。**规则真相源=`design/gpt-image-reference.md`**（尤其 §9-14 小件纪律），本文件只存"当前这一版全文"。资产落位、源档归 `assets/art_src/` 后，对应条目即可删除。
> **出图设置**：一律 1792×1024 横版 · quality high 一步到位 · 不附参考图（v10 模板=纯文字自含）。

## ① 悬停框 v10（✅ 已通过 Eddy 验收·等新图重导入落位）

迭代史：v6 祥云角（角复杂）→ v7 简化钩（角区填棕）→ v7.1 裸线（退化纯色图形）→ v8 像素工艺回调（角上棕阴影）→ v9 反暗角（又退化纯色图形·触发 §14 教训落盘）→ **v10 必备件枚举版=通过**。
落位管线：转透明（三形态工具按图况选）→ 裁整除区 → 整数倍降采样 ≈130×58 → 挂点不变（battle `_tip_panel` StyleBoxTexture·9-slice 边距按新图角区量）。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Subject: a single small rectangular tooltip panel for a game — a flat sheet
of warm cream paper with a painted border; no table, no backdrop, no shadow
beneath it. It must read as a hand-crafted, decorated PIXEL-ART UI
component — visibly ornamented and textured, with chunky pixel steps on
corners and curves. A plain undecorated rectangle is a FAILED result.

Composition lock (CRITICAL): the panel spans the entire canvas edge to
edge; only thin transparent margins remain outside it. Straight-on flat
view, no perspective, no 3D depth.

This panel has exactly FOUR visible features. All four are REQUIRED and
must be clearly present in the final image:

Feature 1 — the border: a slim dark walnut-brown band (#3A2B1E family)
painted flat on the same plane as the paper — ink on the sheet, not a
physical frame, so it casts no shadow. Even thickness all the way around,
about 4 pixels, with pixel-stepped slightly rounded corners and a 1-pixel
near-black outer contour.

Feature 2 — the inner line: just inside the border runs ONE thin pale-cream
line (#FAF3DC family — pale cream, NOT gold), 2 pixels thick, forming one
complete unbroken rectangle. It keeps the same color and the same thickness
along its entire run, through all four corners — never fading, never
breaking. This line must be plainly visible in the result.

Feature 3 — the corner curls: a few pixels inside each of the four corners
of the paper floats ONE bold squared spiral curl — hard right angles only,
two or three turns, strokes 3 pixels thick, in a beige clearly darker than
the paper so it reads at a glance. It is confident decorative LINE WORK:
the paper around it and inside its turns keeps the base cream — no filled
patch, no block, no soft shadow in the corner region.

Feature 4 — the paper texture: warm cream (#F0E2B4 family) carrying a
clearly present tone-on-tone mottling like antique rice paper — tiny
irregular patches 5–8% darker than the base, fine-grained, spread evenly
across the WHOLE sheet with no buildup at edges or corners. The paper must
not look like a flat digital fill. The central area carries no ornament
(reserved for game text) but still carries this same texture.

Even lighting: the sheet is equally bright from edge to edge and into every
corner — no vignette, no corner darkening, no shading where the border
meets the paper.

Small-size discipline (CRITICAL): displayed small in game — every stroke at
least 2 grid pixels thick, no hairline details. No top-to-bottom and no
left-to-right gradient anywhere; all four edges between the corner regions
must be perfectly straight, uniform and tileable (the panel is 9-slice
stretched both ways).

Pixel grid and size: designed on a strict 130×58 pixel grid; border ≈4 px,
inner line 2 px, each corner curl within ≈16×14 px; final in-game size
≈130×58 px before 9-slice stretching.

Final self-check — the image FAILS if ANY of these is true:
· any of the four features is missing or barely visible — a bare flat
  rectangle is JUST AS WRONG as an over-decorated one;
· there is a dark smudge, shadow or filled patch in any corner;
· there is gold or yellow trim, a directional gradient, or hairline
  strokes.

Output: one single panel spanning the entire canvas width edge to edge,
centered vertically, front view, flat, on a fully transparent background
(PNG with alpha).
```

## ② 导航钮 v9「朱印落款」（C 方案·Eddy 选定·⏳ 待出图）

设计定案（2026-07-14 Eddy 选 C）：素暖纸签牌+胡桃木扁平边框，**右端一枚 ≈18×18 小朱印**（中式落款位·全图唯一红·印面=抽象方折纹章禁文字）。语义=点击即盖印；朱印是设计规范"鎏金+朱印点睛"里全 UI 唯一使用者。⛔ 不复用卷轴语言（Eddy：卷轴够多了）·⛔ 金/内圈（两次否决）。
迭代史：v5 极简版（出图复杂+金内圈）→ v6/v7 同构被否（和旧设计没区别）→ v8 木骨签牌（卷轴复用被否）→ **v9=C 朱印落款**。
落位管线：同悬停框；9-slice **右边距按印章实际位置量后钉死（≥26px）**·战斗 128×128 图鉴钮同图复用印章保形。挂点=main_menu `_make_plate_bg`+battle `BtnCodex`+图鉴返回钮（NAV_PLATE_MARGIN 三处同步改）。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Subject: a single wide horizontal navigation button for a game's main menu
— a flat tablet of warm paper with a painted border, marked with one small
vermilion seal stamp like a signature chop on a document; no table, no
backdrop, no shadow beneath it. It must read as a hand-crafted, decorated
PIXEL-ART UI component with chunky pixel steps on corners and curves — NOT
a plain rectangle, and NOT a photograph of a real object.

Composition lock (CRITICAL): the tablet spans the entire canvas edge to
edge; only thin transparent margins remain outside it. Straight-on flat
view, no perspective, no 3D depth, no bevel highlights.

This tablet has exactly THREE visible features. All three are REQUIRED and
must be clearly present in the final image:

Feature 1 — the border: a slim dark walnut-brown band (#3A2B1E family)
painted flat on the same plane as the paper — ink on the sheet, not a
physical frame, so it casts no shadow. Even thickness all the way around,
about 3 pixels, with pixel-stepped slightly rounded corners and a 1-pixel
near-black outer contour. This is the tablet's ONLY border: no inner line,
no inner ring, no gold anywhere.

Feature 2 — the seal: near the RIGHT end of the paper sits ONE small
square vermilion seal stamp, about 18×18 pixels, in cinnabar seal-paste
red (#B03A2A family) — the ONLY red in the image. It looks hand-stamped:
slightly uneven inked edges with visible pixel steps, and inside it a
simple abstract squared-spiral emblem shows through in the paper color —
an abstract geometric mark ONLY: no letters, no Chinese characters, no
readable glyph of any kind. The seal sits fully inside the outer 26 pixels
of the right end, the paper around it stays unchanged — no shadow, no
glow, no ink smear beyond its edges.

Feature 3 — the paper face: warm tea paper (#E8D2A0 family) carrying a
clearly present tone-on-tone mottling like antique rice paper — tiny
irregular patches 5–8% darker than the base, fine-grained, spread
perfectly evenly across the whole face with no buildup at edges or
corners. The face must not look like a flat digital fill. The central
stretch stays free of ornament (button text is rendered by the game
engine).

Even lighting: the tablet is equally bright from edge to edge and into
every corner — no vignette, no corner darkening, no shading where the
border meets the paper.

Small-size discipline (CRITICAL): displayed small in game — every stroke
at least 3 grid pixels thick (the 1-pixel contour is the only exception);
no hairline details. No directional gradient anywhere; the central stretch
of the paper must be perfectly uniform and horizontally tileable (the
tablet is 9-slice stretched both ways; the seal zone at the right end
stays fixed).

Pixel grid and size: designed on a strict 220×49 pixel grid; border ≈3 px,
the seal ≈18×18 px inside the right-end 26 px zone; final in-game size
≈ 220×49 px before 9-slice stretching.

Final self-check — the image FAILS if ANY of these is true:
· any of the three features is missing or barely visible — a bare flat
  rectangle is JUST AS WRONG as an over-decorated one;
· red appears anywhere other than the single seal, or the seal contains
  anything resembling letters or characters;
· there is any gold, metallic trim, inner ring or second border;
· there is a dark smudge, shadow or filled patch at any end or corner;
· there is a directional gradient or hairline strokes.

Output: one single tablet spanning the entire canvas width edge to edge,
centered vertically, front view, flat, on a fully transparent background
(PNG with alpha).
```

### 导航钮备选（C 不合意再展开）

- **B 横匾缩印式**：牌匾双线边+角回折缩到按钮档；正式感最强·风险=与标题牌匾抢层级。
- **D 祥云托角式**：素签牌+左下角一缕同色系祥云；柔和·风险=低对比下存在感不足。
- **E 界画双线式**：外胡桃木线+内细墨线+回字角·无点缀色；最克制最退后。
