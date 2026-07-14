# 现役 UI 小件 prompt 存档（2026-07-14）

> **用途**：未完成落位的小件出图 prompt 快照——防 session 切换丢失。**规则真相源=`design/gpt-image-reference.md`**（尤其 §9-14 小件纪律），本文件只存"当前这一版全文"。资产落位、源档归 `assets/art_src/` 后，对应条目即可删除。
> **出图设置**：一律 1792×1024 横版 · quality high 一步到位。**范式改定（2026-07-14 Eddy）：对齐资产而非文档——小件 prompt 一律挂在役资产单参考（§13 取舍逐条点名防泄漏），⛔纯文字自含模板（v6-v10 两轮马拉松实证=只会出泛 JRPG 面板）。**

## ① 悬停框 v11「族语归位·回纹角内线」（✅ 已落位 2026-07-14·全文留作单参考范式成功模板）

> **落位实录**：出图白底→img_checker_to_alpha→裁 (22,20,1834,798)→÷14=**131×57**→assets/ui/ui_tooltip.png；battle `_tip_panel` texture_margin 14→**20**（实测钩横笔 y≤11/≥45·深≤18）；tip_probe 三截图目检过；源档=art_src/ui/ui_tooltip.png（旧版加 `_retired` 后缀保留）。

**v10 复判不通过（2026-07-14 Eddy：不符合已有 UI 风格·甚至不如实装包角版）**。病根两条：①v10 的"漂浮方折涡卷+奶油内线"在任何在役资产上都不存在=凭文档臆造；②纯文字不挂参考=对不齐族语。
**资产实读（2026-07-14 取色扫描 `scratchpad/color_scan.gd`·色值以资产为准，docs 令牌有偏差）**：
- 家族两种构成：**A「深框浅芯」**=悬停框实装独一份（近黑浓缩咖啡框 `#130C08`+奶油纸 `#F3E4BC`+淡金细线角回折+四角包角块）——战场悬浮件；**B「浅骨深纹」**=头像框/道具框/导航钮/牌匾（茶金纸 `#F0D7A2`+深巧克力纹线 `#4F2B14`+暖木棕带 `#7B4728`+近黑描边 `#321B08`）——图鉴/菜单件。
- **签名母题=回纹方折钩**：头像框四角/道具框四角/导航钮两端/牌匾内线角回折全在用；实装悬停框=全家族唯一无回纹件。
- **纸纹真相**：资产纸纹=细而匀、近看有远看静（导航钮=极淡菱纹）；v10"clearly present 5-8% 斑驳"方向本身就错。
**v11 设计=悬停框归队**：保实装版优点（近黑承重框=战场分离度·奶油净面·比例不变），唯一替换=包角块+淡金线 → **深巧克力内线+四角回纹钩**（牌匾/头像框同语言）。每个元素可指到一件在役资产。
**参考图=`assets/art_src/ui/ui_plaque.png` 单参考**（取：巧克力内线+回纹角形制+纸纹细度+暖调；弃：切角轮廓/骨色外缘/横幅比例）。
落位管线：转透明（三形态工具按图况选）→ 裁整除区 → 整数倍降采样 ≈130×58 → 挂点不变（battle `_tip_panel` StyleBoxTexture·9-slice 边距按角区实量·预估 ~20 含回纹钩）。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is the finalized title plaque from this game's UI set —
same family, painted by the same hand. The new asset must look like it
belongs to exactly this set. From image 1 take ONLY: the dark chocolate
inner line and the way it turns into small squared meander hooks at its
corners, the fine quiet paper grain, and the warm palette. IGNORE from
image 1: its cut-corner octagonal silhouette, its pale outer rim, and its
long banner proportions — the new asset does not copy its layout.

Subject: a single small rectangular tooltip panel for the same game — a
flat sheet of warm cream paper held in a heavy dark painted frame; no
table, no backdrop, no glow, no shadow beneath it. It must read as a
hand-crafted PIXEL-ART UI component from the same set as image 1, with
chunky pixel steps on corners and curves — a plain undecorated rectangle
is a FAILED result.

Composition lock (CRITICAL): the panel spans the entire canvas edge to
edge; only thin transparent margins remain outside it. Straight-on flat
view, no perspective, no 3D depth, no bevels.

This panel has exactly FOUR visible features. All four are REQUIRED and
must be clearly present in the final image:

Feature 1 — the outer frame: a chunky near-black espresso band (#130C08
family), about 5 pixels thick, painted flat on the same plane as the
paper, even thickness all the way around, with pixel-stepped slightly
rounded corners. This is the heaviest, darkest element of the panel — the
panel floats over a busy game scene and this frame is what separates it.

Feature 2 — the inner line: about 3 pixels inside the frame runs ONE thin
dark-chocolate line (#4F2B14 family — brown ink like image 1's inner
line, NOT gold, NOT metallic), 2 pixels thick, forming one complete
unbroken rectangle, keeping the same color and thickness along its entire
run.

Feature 3 — the four corner hooks: at each of the four corners of that
inner line, the line turns into a small squared meander hook — the same
corner motif as image 1: hard right angles only, about two turns, strokes
2 pixels thick, each hook fitting inside a zone of about 12×10 pixels.
All four corners carry the same hook. The paper around and inside each
hook keeps the base cream — pure line work, no filled patch, no block,
no shadow in the corner region.

Feature 4 — the paper face: warm cream paper (#F3E4BC family) carrying a
fine, quiet tone-on-tone grain like the paper in image 1 — tiny specks a
few percent darker than the base, fine-grained and evenly spread, visible
up close but calm at a glance. NOT heavy blotches, NOT noise, and NOT a
flat digital fill. The central area carries no ornament (game text is
rendered there by the engine) but still carries this same grain.

Even lighting: the sheet is equally bright from edge to edge and into
every corner — no vignette, no corner darkening, no glow around the
panel, no shading where the frame meets the paper.

Small-size discipline (CRITICAL): displayed small in game — every stroke
at least 2 grid pixels thick (nothing thinner anywhere); the frame band
about 5. No top-to-bottom and no left-to-right gradient anywhere; all
four edges between the corner zones must be perfectly straight, uniform
and tileable (the panel is 9-slice stretched both ways; only the four
corner zones stay fixed).

Pixel grid and size: designed on a strict 130×58 pixel grid; frame ≈5 px,
inner line 2 px, each corner hook within ≈12×10 px; final in-game size
≈130×58 px before 9-slice stretching.

Final self-check — the image FAILS if ANY of these is true:
· any of the four features is missing or barely visible — a bare flat
  rectangle is JUST AS WRONG as an over-decorated one;
· the corner hooks are missing, curved, or replaced by filled blocks;
· there is any gold, metallic trim, or a third line;
· the panel copies image 1's cut-corner silhouette or banner proportions;
· there is a glow, halo, drop shadow or any backdrop around the panel;
· there is a dark smudge or filled patch in any corner, a directional
  gradient, or hairline strokes.

Output: one single panel spanning the entire canvas width edge to edge,
centered vertically, front view, flat, on a fully transparent background
(PNG with alpha).
```

## ② 导航钮 v12「回纹抱端签牌」（✅ 已落位 2026-07-14·全文留作单参考范式成功模板）

> **落位实录**：出图实色底+泛光→img_bg_flood_to_alpha→裁 (99,330,1338,312)→÷6=**223×52**→assets/ui/ui_nav_button.png；9-slice 边距四向不对称=**左右 21/上下 15**（实测抱端深 18-19·钩横笔 y0-13/39-51·中段带=纯竖线+纸→双向 TILE 安全·128 方钮实证保形）；三挂点同步（main_menu 常量拆 X/Y+battle codex_bg+图鉴 NAV_PLATE_MARGIN_X/Y）；menu/图鉴/tip_probe 截图目检过·GUT 360 绿；源档=art_src/ui/ui_nav_button.png（旧版 `_retired` 保留）。⚠ 纸面残留 ~2-3% 纵向泛光渐变：边距设置后平铺带内仅 ~2%·截图未见百叶窗；若后续大尺寸挂点出现横缝→img_flatten_rows（⚠边距参数须避开钩行）。

**范式=悬停框 v11 同款（2026-07-14 验证通过）：在役资产单参考+族语归位。**
设计=**牌匾的直角矩形亲戚**：暖茶纸签牌（`#EFD6A1`·现役钮实测同色）+暖木棕细边框（`#7B4728`=牌匾外带实测色+近黑描边 `#321B08`）+**深巧克力内线两端收「回纹抱端」**（`#4F2B14`·内线长边直行·两端各收一组上下双钩夹竖折的端返=牌匾内线端头同构）+细匀纹。
- **vs 旧版（回纹钩版）**：旧钩=漂浮孤件、无内线；v12=**线生钩**（钩长在连续内线端头上·牌匾同构）+边框带描边——构造级区别，非换皮。
- **vs 悬停框 v11**：框轻色暖（浅骨深纹）vs 框重色黑（深框浅芯）·钩在两端 vs 四角·茶纸 vs 奶油纸。
- **vs 牌匾**：牌匾=切角+骨缘+最大；导航钮=直角+无骨缘——减法分层不抢位（原备选 B"横匾缩印"由此吸收且规避其抢层级风险）。
- **9-slice 保形自证**：端头双钩落上下角区（固定）·竖折落左右边带（纵向拉伸=直线变长无损）·长边直行可平铺——128×128 战斗图鉴钮双向拉伸全安全。
⛔ 累计红线：朱砂印/红点缀（v9/v10）·卷轴复用含滚轴圆头帽（v8）·金/金内圈（v5）·切角轮廓=牌匾形制（v11 教训）·漂浮孤钩=旧版同构（v6/v7）·素板（§14）。
迭代史：v5 金内圈⛔ → v6/v7 同构⛔ → v8 卷轴复用⛔ → v9/v10 朱砂印⛔ → v11 切角挂起（与牌匾撞形制+纯文字范式证伪）→ **v12=回纹抱端（资产参考范式）**。
参考图=`assets/art_src/ui/ui_plaque.png` 单参考（取：内线+端返双钩形制+茶纸与纹理+木棕带色+暖调；弃：切角轮廓/骨色外缘/横幅比例）。
落位管线：转透明→裁整除区→整数倍降采样≈220×49→三挂点同步（main_menu `_make_plate_bg`+battle `codex_bg` battle_screen.gd ~L467+图鉴 `NAV_PLATE_MARGIN`）·9-slice 边距按新图实量（预估左右 ~24 盖抱端·上下 ~14 盖钩+框·四向不对称）·TILE。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is the finalized title plaque from this game's UI set —
same family, painted by the same hand. The new asset must look like it
belongs to exactly this set. From image 1 take ONLY: the dark chocolate
inner line and the way it steps into squared meander returns at its two
ends, the warm tea paper with its fine quiet grain, and the warm
wood-brown of its border. IGNORE from image 1: its cut-corner octagonal
silhouette, its pale outer rim, and its banner proportions — the new
asset does not copy its layout.

Subject: a single wide horizontal navigation button for the same game — a
flat tablet of warm tea paper with a slim wood-brown border, decorated by
an inner ink line that gathers into squared meander brackets at the left
and right ends; no table, no backdrop, no glow, no shadow beneath it. It
must read as a hand-crafted PIXEL-ART UI component from the same set as
image 1, with chunky pixel steps on corners and curves — a plain
undecorated rectangle is a FAILED result.

Composition lock (CRITICAL): the tablet spans the entire canvas edge to
edge; only thin transparent margins remain outside it. Straight-on flat
view, no perspective, no 3D depth, no bevels. The tablet itself is a
plain wide rectangle with slightly rounded pixel-stepped corners — its
corners are NOT cut off diagonally.

This tablet has exactly FOUR visible features. All four are REQUIRED and
must be clearly present in the final image:

Feature 1 — the border: a slim warm walnut-brown band (#7B4728 family,
the same brown as image 1's border), about 3 pixels thick, painted flat
on the same plane as the paper, even thickness all the way around, with
pixel-stepped slightly rounded corners and a 1-pixel near-black (#321B08)
contour on its outside.

Feature 2 — the inner line: about 3 pixels inside the border runs ONE
thin dark-chocolate line (#4F2B14 family — brown ink like image 1's inner
line, NOT gold, NOT metallic), 2 pixels thick. Its long top and bottom
runs are perfectly straight, parallel to the border, and keep the same
color and thickness along their entire length.

Feature 3 — the end brackets: at the LEFT end and at the RIGHT end, the
inner line does not simply close into a rectangle — it steps inward and
curls into a pair of squared meander hooks, one at the top and one at
the bottom, joined by a short vertical run: one bracket per end, the two
ends mirrored, exactly the same end-return motif as image 1's inner
line. Hard right angles only, strokes 2 pixels thick, each bracket
fitting inside the outer 24 pixels of its end. The paper around and
inside the hooks keeps the base tea color — pure line work, no filled
patch, no block, no shadow at the ends.

Feature 4 — the paper face: warm tea paper (#EFD6A1 family, like the
center of image 1) carrying a fine, quiet tone-on-tone grain — tiny
specks a few percent darker than the base, fine-grained and evenly
spread, visible up close but calm at a glance. NOT heavy blotches, NOT
noise, and NOT a flat digital fill. The central stretch carries no
ornament (button text is rendered there by the game engine) but still
carries this same grain.

Even lighting: the tablet is equally bright from edge to edge and into
every corner — no vignette, no corner darkening, no glow around the
tablet, no shading where the border meets the paper.

Small-size discipline (CRITICAL): displayed small in game — every stroke
at least 2 grid pixels thick (the 1-pixel contour is the only exception);
the border band about 3; no hairline details. No top-to-bottom and no
left-to-right gradient anywhere; the long top and bottom runs and the
central paper must be perfectly straight, uniform and tileable (the
tablet is 9-slice stretched both ways; only the two end-bracket zones
and the four corners stay fixed).

Pixel grid and size: designed on a strict 220×49 pixel grid; border ≈3 px
plus 1 px contour, inner line 2 px, each end bracket within the outer
24 px of its end; final in-game size ≈220×49 px before 9-slice
stretching.

Final self-check — the image FAILS if ANY of these is true:
· any of the four features is missing or barely visible — a bare flat
  rectangle is JUST AS WRONG as an over-decorated one;
· the end brackets are missing on either end, curved, or replaced by
  filled blocks;
· the corners are cut off diagonally (copying image 1's silhouette), or
  the tablet copies image 1's pale outer rim;
· there is any red mark or seal, any gold or metallic trim;
· there are scroll rollers, round end caps, or anything protruding
  beyond the rectangle;
· there is a dark smudge or filled patch anywhere, a directional
  gradient, or hairline strokes.

Output: one single tablet spanning the entire canvas width edge to edge,
centered vertically, front view, flat, on a fully transparent background
(PNG with alpha).
```

### 导航钮备选（v12 仍不合意再展开）

- **D 祥云托角式**：素签牌+一角同色系祥云（tab_cloud 族语）；柔和·风险=低对比下存在感不足。
- **E 界画双线式**：方角+双线+回字角、无端饰；比 v12 更收敛的退路。
- ~~B 横匾缩印式~~：**已由 v12 吸收**（直角+去骨缘=规避抢牌匾层级的原风险）。
- ⛔ 已排除：朱砂印/红点缀·卷轴复用（含滚轴/圆头帽）·金/金内圈·切角轮廓（=牌匾形制·v11 教训）·漂浮孤钩（=旧版同构）·素板。
