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

## ② 导航钮（现役=v12b·v13 修正 ⏳ 待出图）

### v14「头像框回纹实钩移植」（现役 ⏳ 待出图·UI 重构 Epic 项③·2026-07-15）

> Eddy 否 v13 方向：**内饰根本不是纹理、是简笔画**——病根=单线细螺旋本身就是简笔画体质，翻卷向救不了。
> **新教训入红线池：纹样要读作纹理必须"粗笔+实心芯"——单线卷=简笔画**（v12b 轱辘/v13 翻向 两代实证）。
> v14=对齐在役资产形制（Eddy：有必要就对齐其他美术资产）：**四角轱辘全废→移植 hero_avatar_frame 的
> 回纹实钩**（家族旗舰纹样：粗笔方折+螺旋芯收一颗实心方块+向内卷向面板——正好同时满足 v13 的内卷要求）。
> 双参考分工（§13 验证写法）：image1=`art_src/ui/ui_nav_button.png`（锁钮身：比例/纸纹/边框/内线·
> ⛔忽略其四角简笔卷）+image2=`art_src/ui/hero_avatar_frame.png`（只取角部回纹实钩构造·⛔忽略方形比例/框形/尺寸）。
> 落位管线（v12b 同款）：checker_to_alpha→裁÷k≈235×55→img_ring_recolor 外框浓缩咖啡阶→同路径替换
> →--import→9-slice 边距按新图实量（角部钩区必须全落固定区）→三挂点截图目检→GUT。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is this game's current navigation button. It is the
design authority for everything EXCEPT its corner ornaments: reproduce
faithfully its proportions, its warm tea paper with the fine quiet grain,
its wood-brown border with the thin dark outer contour, and its
dark-chocolate inner line with its long straight runs. COMPLETELY IGNORE
image 1's four corner ornaments — those thin curling single-line scrolls
are exactly what is being replaced; do not reproduce them in any form.

Attached image 2 is this game's hero portrait frame — same set, painted
by the same hand. From image 2 take ONLY its corner ornament
construction: at each corner the inner line gathers into a squared
meander fret — a CHUNKY hook of hard right angles that coils INWARD and
closes on a SOLID FILLED SQUARE at its heart. Thick confident strokes
with the filled square eye make it read as carved ornament, as pattern —
never as a drawn line. IGNORE everything else about image 2: its square
proportions, its double-frame layout, its size.

Subject: the same navigation button as image 1 with its four corner
ornaments replaced by image 2's corner frets. It must read as a
hand-crafted PIXEL-ART UI component from the same set as both references.

Composition lock (CRITICAL): the button spans the entire canvas edge to
edge; only thin transparent margins remain outside it. Straight-on flat
view, no perspective, no 3D depth, no bevels. The silhouette stays as in
image 1 — corners NOT cut off diagonally, nothing protruding.

This button has exactly FOUR visible features. All four are REQUIRED:

Feature 1 — the border: image 1's slim wood-brown band with its thin
dark outer contour, even thickness all the way around, unchanged.

Feature 2 — the inner line: image 1's single dark-chocolate line, its
long top and bottom runs perfectly straight, uniform color and thickness
along their entire length, unchanged.

Feature 3 — the corner frets (THE replacement): at each of the four
corners the inner line gathers into a squared meander fret exactly in
the manner of image 2's corners: stroke about 3 pixels thick, hard right
angles only, coiling INWARD so that its solid filled square eye sits
toward the paper field's center — never opening outward. One fret per
corner, all four mirror-symmetric (left/right mirrored, top/bottom
mirrored), each fret compact and fitting inside the outer 30 pixels of
its corner, joined seamlessly to the inner line's runs. The fret is
line-plus-eye ornament painted directly on the paper — the tea paper
stays visible around and between its coils; no filled background patch
behind it. A single thin curling line here is a FAILED result — the
fret must carry the thick stroke and the solid square eye of image 2.

Feature 4 — the paper face: image 1's warm tea paper carrying the same
fine, quiet tone-on-tone grain — visible up close, calm at a glance.
The central stretch stays empty (button text is rendered by the game
engine) but still carries this same grain.

Even lighting: equally bright edge to edge and into every corner — no
vignette, no corner darkening, no glow, no shading where border meets
paper.

Small-size discipline (CRITICAL): designed on a strict 235×55 pixel
grid, final in-game size ≈235×55 px before 9-slice stretching — every
stroke at least 2 grid pixels thick, fret strokes about 3; no hairline
details; no top-to-bottom or left-to-right gradient anywhere; the long
middle stretch stays uniform and tileable (the button is 9-slice
stretched both ways; only the corner fret zones stay fixed).

Final self-check — the image FAILS if ANY of these is true:
· any corner ornament is a thin single-line scroll or doodle instead of
  a thick squared fret with a solid filled square eye;
· any fret coils outward, or its eye faces away from the paper center;
· frets are missing on any corner, asymmetric, detached from the inner
  line, or spill outside their corner zones toward the middle;
· anything else changed versus image 1 — new ornament, removed grain,
  different colors, cut-off corners, gold or metallic trim, red marks;
· a glow, halo, drop shadow or backdrop appears anywhere;
· OR the opposite failure: an over-decorated result — extra pattern on
  the paper, doubled lines, or ornament beyond the four corner frets.

Output: one single button spanning the entire canvas width edge to edge,
centered vertically, front view, flat, on a fully transparent background
(PNG with alpha).
```

### ~~v13「轱辘内卷」修正版~~（⛔ 已否·Eddy：内饰仍是简笔画非纹理·翻卷向救不了·换形制=v14）

> Eddy 验收 v12b：外观配色没有大问题·**唯一问题=内线四角轱辘（方折螺旋卷）卷口朝外开——现实中没有或极少见**
> （中式家具/画框回纹角花均向内卷向面板）→ v13=**照参考忠实重绘只改点名处**（§13 正解范式）：
> image1=现役钮唯一设计权威·全图原样重绘·只翻四角轱辘卷向（卷口+芯尖朝纸面中心·四角镜像对称）。
> 参考图 image1=`assets/art_src/ui/ui_nav_button.png`（高清原档·⚠出图回来外框仍是中棕=正常，
> 落位管线会重跑 img_ring_recolor 换浓缩咖啡阶——v12b 同规）。
> 落位管线（v12b 同款）：checker_to_alpha→裁整除区→÷k≈235×55→img_ring_recolor 外框带三档映射
> （140a04/1a0e05/221107）→同路径替换 assets/ui/ui_nav_button.png→--import→9-slice 边距按新图实量
> →三挂点截图目检（menu/battle 方钮/图鉴返回）→GUT。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is this game's current navigation button. It is the ONLY
design authority for this task: the new image is a FAITHFUL REDRAW of
image 1 — same proportions, same warm tea paper with its fine quiet grain,
same wood-brown border with its thin dark outer contour, same
dark-chocolate inner line with its long straight runs, same overall size
and layout. Do not redesign, do not restyle, do not add or remove any
element.

The ONE and ONLY change (CRITICAL): in image 1 the inner line ends, at
each of the four corners, in a small squared spiral scroll that curls
OUTWARD, its opening facing away from the paper field. Real furniture
and frame corner scrolls never do this. Flip the direction: redraw each
of the four corner spirals so it curls INWARD — each spiral's opening
and its innermost tip must face the CENTER of the paper field, the way
squared meander corner motifs sit on real Chinese furniture frames. Keep
everything else about the spirals unchanged: same stroke thickness (2-3
pixels), same hard right angles only (no curved strokes), same size
(each spiral stays inside its original corner zone), same dark-chocolate
color, still joined to the inner line exactly where they join now, pure
line work with the tea paper showing around and inside the coils. The
four corners stay mirror-symmetric: left/right mirrored, top/bottom
mirrored.

Composition lock (CRITICAL): the button spans the entire canvas edge to
edge; only thin transparent margins remain outside it. Straight-on flat
view, no perspective, no 3D depth, no bevels. The silhouette stays as in
image 1 — corners NOT cut off diagonally, nothing protruding.

Everything-else-identical checklist — all of these must match image 1:
· the slim wood-brown border band with its thin dark outer contour;
· the single dark-chocolate inner line, perfectly straight along the top
  and bottom runs, uniform color and thickness over its whole length;
· the warm tea paper face with its fine, quiet tone-on-tone grain —
  visible up close, calm at a glance; the central stretch stays empty
  (button text is rendered by the game engine);
· even lighting edge to edge — no vignette, no glow, no corner darkening.

Small-size discipline (CRITICAL): designed on a strict 235×55 pixel grid,
final in-game size ≈235×55 px before 9-slice stretching — every stroke at
least 2 grid pixels thick (the 1-pixel outer contour is the only
exception); no hairline details; no top-to-bottom or left-to-right
gradient anywhere; the long middle stretch stays uniform and tileable
(the button is 9-slice stretched both ways; only the end zones and
corners stay fixed).

Final self-check — the image FAILS if ANY of these is true:
· any corner spiral still opens outward, away from the paper center;
· the spirals became curved scrolls instead of hard right-angle meanders,
  grew or shrank outside their corner zones, or detached from the inner
  line;
· anything else changed versus image 1 — new ornament, removed grain,
  different colors, cut-off corners, gold or metallic trim, red marks;
· a glow, halo, drop shadow or backdrop appears anywhere.

Output: one single button spanning the entire canvas width edge to edge,
centered vertically, front view, flat, on a fully transparent background
(PNG with alpha).
```

### v12「回纹抱端签牌」（✅ 已落位 2026-07-14·全文留作单参考范式成功模板）

> **落位实录 v12a（首版·已退役）**：出图实色底+泛光→flood_to_alpha→÷6=223×52·边距左右21/上下15。Eddy 判**外框中棕太淡**→退役（源档 `_v12a_light_border_retired` 保留）。
> **落位实录 v12b（现役·2026-07-14 二版）**：Eddy 重出图（棋盘格底）→img_checker_to_alpha→裁 (27,110,2115,495)→÷9=**235×55**→**外框环带换色对齐悬停框族色**（新工具 `tools/img_ring_recolor.gd`：BFS 距透明轮廓≤5px ∩ V<0.62 选外框带→三档映射浓缩咖啡阶 `140a04/1a0e05/221107`=ui_tooltip `#1F1006` 族；内线/抱端在环带外不动）→assets/ui/ui_nav_button.png；9-slice 边距=**左右 21/上下 18**（实测抱端深 18·钩横笔 y0-16/37-54）三挂点同步；menu/battle 方钮/图鉴返回钮截图目检过（近黑框在夜景/亮纸分离度均优于中棕版）·GUT 376 绿；源档=art_src/ui/ui_nav_button.png。

**范式=悬停框 v11 同款（2026-07-14 验证通过）：在役资产单参考+族语归位。**
设计=**牌匾的直角矩形亲戚**：暖茶纸签牌（`#EFD6A1`·现役钮实测同色）+暖木棕细边框（`#7B4728`=牌匾外带实测色+近黑描边 `#321B08`）+**深巧克力内线两端收「回纹抱端」**（`#4F2B14`·内线长边直行·两端各收一组上下双钩夹竖折的端返=牌匾内线端头同构）+细匀纹。
- **vs 旧版（回纹钩版）**：旧钩=漂浮孤件、无内线；v12=**线生钩**（钩长在连续内线端头上·牌匾同构）+边框带描边——构造级区别，非换皮。
- **vs 悬停框 v11**：框轻色暖（浅骨深纹）vs 框重色黑（深框浅芯）·钩在两端 vs 四角·茶纸 vs 奶油纸。
- **vs 牌匾**：牌匾=切角+骨缘+最大；导航钮=直角+无骨缘——减法分层不抢位（原备选 B"横匾缩印"由此吸收且规避其抢层级风险）。
- **9-slice 保形自证**：端头双钩落上下角区（固定）·竖折落左右边带（纵向拉伸=直线变长无损）·长边直行可平铺——128×128 战斗图鉴钮双向拉伸全安全。
⛔ 累计红线：朱砂印/红点缀（v9/v10）·卷轴复用含滚轴圆头帽（v8）·金/金内圈（v5）·切角轮廓=牌匾形制（v11 教训）·漂浮孤钩=旧版同构（v6/v7）·素板（§14）·**单线细螺旋轱辘=简笔画非纹理——纹样必须粗笔+实心芯（v12b/v13 两代实证·2026-07-15）**。
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

## ③ 抽卡衬纸 v1「悬停框竖版亲戚」（F 件·✅ 已落位 2026-07-14·一次过）

> **落位实录**：白底→checker_to_alpha→裁 (16,14,1052,1420)→÷4=**263×355**→assets/ui/item_draft_card.png（定尺寸展示不吃 9-slice·CARD_W/H 常量跟随实寸改）；item_draft_popup 重构=jelly 稀有度芯片/DIM_COLOR/_make_card_jelly 死码全清→纸卡贴图+卡名 TIER_INK 三阶+图标套 item_frame_t1/2/3 阶框（128 原生尺寸）+**格底=图鉴同配方**（CELL_BG_SHADER 四角深阶色/中心略浅/传说 gold_bottom·Eddy 补正"抽卡格底须与图鉴一致"）+分隔墨线+描述墨字直书（scrim/白字描边退役）+取消钮穿导航钮皮；tip_draft 截图目检过·GUT 376 绿；源档=art_src/ui/item_draft_card.png。

设计（§15 范式·2026-07-14）：3选1 抽卡 240×320 卡面换纸——**深框浅芯构成竖版化**（近黑框+奶油纸+巧克力内线+四角回纹钩=悬停框 v11 已过同款·两者同为"浮在战场上的纸面件"）。**资产稀有度中性一张图**（⛔整图染·§10）：稀有度=卡名墨色三阶 TIER_INK（34608F/6B3D96/8F6A1E·图鉴小卷轴同规）+图标外套现役 item_frame_t1/2/3 阶框（引擎侧复用）；描述暗底 scrim 退役=墨字直书纸面。
参考图=`assets/art_src/ui/ui_tooltip.png` 单参考（取：框色框重+内线回纹角形制+纸色纸纹；弃：横版比例与小尺寸）。
落位管线：出图 1024×1792 竖版→转透明→量边界→k=round(w/240) 裁整除→÷k（**最终尺寸就近浮动·item_draft_popup CARD_W/H 常量跟随实量改**·卡是定尺寸展示不吃 9-slice 拉伸）→ _build_card jelly 芯片退役换贴图+pop 动画保留；引擎侧配套=名字染 TIER_INK/图标阶框/描述墨字（落位批一起做）。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is the finalized tooltip panel from this game's UI set —
same family, painted by the same hand. The new asset must look like it
belongs to exactly this set. From image 1 take ONLY: the near-black frame
color and weight, the dark chocolate inner line and the way it turns into
small squared meander hooks at its four corners, and the warm cream paper
with its fine quiet grain. IGNORE from image 1: its small size and wide
landscape proportions — the new asset is a large PORTRAIT card.

Subject: a single tall reward-card backing for the same game — a flat
sheet of warm cream paper held in a heavy dark painted frame, portrait
orientation like a playing card; no table, no backdrop, no glow, no
shadow beneath it. It must read as a hand-crafted PIXEL-ART UI component
from the same set as image 1, with chunky pixel steps on corners and
curves — a plain undecorated rectangle is a FAILED result.

Composition lock (CRITICAL): the card is a portrait rectangle with
width : height = 3 : 4, spanning the entire canvas width edge to edge and
centered vertically; only transparent margins remain above and below.
Straight-on flat view, no perspective, no 3D depth, no bevels.

This card has exactly FOUR visible features. All four are REQUIRED and
must be clearly present in the final image:

Feature 1 — the outer frame: a chunky near-black espresso band (#1F1006
family, the same color as image 1's frame), about 6 pixels thick, painted
flat on the same plane as the paper, even thickness all the way around,
with pixel-stepped slightly rounded corners. This is the heaviest,
darkest element — the card floats over a busy game scene and this frame
is what separates it.

Feature 2 — the inner line: about 4 pixels inside the frame runs ONE thin
dark-chocolate line (#4F2B14 family — brown ink like image 1's inner
line, NOT gold, NOT metallic), 3 pixels thick, forming one complete
unbroken rectangle, keeping the same color and thickness along its entire
run.

Feature 3 — the four corner hooks: at each of the four corners of that
inner line, the line turns into a small squared meander hook — the same
corner motif as image 1: hard right angles only, about two turns, strokes
3 pixels thick, each hook fitting inside a zone of about 18×16 pixels.
All four corners carry the same hook. The paper around and inside each
hook keeps the base cream — pure line work, no filled patch, no block,
no shadow in the corner region.

Feature 4 — the paper face: warm cream paper (#F3E4BC family, like
image 1) carrying a fine, quiet tone-on-tone grain — tiny specks a few
percent darker than the base, fine-grained and evenly spread, visible up
close but calm at a glance. NOT heavy blotches, NOT noise, and NOT a flat
digital fill. The whole central area stays completely empty — no icon, no
emblem, no picture, no divider, no mark of any kind (the item name, icon
and description are all rendered by the game engine on top).

Even lighting: the sheet is equally bright from edge to edge and into
every corner — no vignette, no corner darkening, no glow around the card,
no shading where the frame meets the paper.

Small-size discipline (CRITICAL): displayed small in game — every stroke
at least 3 grid pixels thick (the frame band about 6); no hairline
details. No top-to-bottom and no left-to-right gradient anywhere; all
four edges between the corner zones must be perfectly straight and
uniform.

Pixel grid and size: designed on a strict 240×320 pixel grid; frame
≈6 px, inner line 3 px, each corner hook within ≈18×16 px; final in-game
size ≈240×320 px, displayed at fixed size (no stretching).

Final self-check — the image FAILS if ANY of these is true:
· any of the four features is missing or barely visible — a bare flat
  rectangle is JUST AS WRONG as an over-decorated one;
· the corner hooks are missing, curved, or replaced by filled blocks;
· there is any icon, picture, emblem or divider drawn on the paper;
· there is any gold, metallic trim, red mark, or a third line;
· there is a glow, halo, drop shadow or any backdrop around the card;
· there is a dark smudge or filled patch in any corner, a directional
  gradient, or hairline strokes;
· the card is landscape instead of portrait 3:4.

Output: one single portrait card spanning the entire canvas width edge to
edge, centered vertically, front view, flat, on a fully transparent
background (PNG with alpha).
```

## ④ 鼠标指针（G 件·B 方案「族语化经典箭头」）

> 沿革：v1 如意云头⛔（Eddy 2026-07-15 否·联想弱+云头喧宾）→ v2 程序自产⛔（"底部有个不协调拐弯"=直角甩尾硬伤·
> 生成器 tools/gen_ui_cursor.gd 仍在库可重跑·其产出贴图已被 5d6c00f GPT 版覆盖·原件可从 git 60f486f 找回）
> → v3.1 GPT 暖色经典箭头（2026-07-15 出图落位 5d6c00f）⛔ Eddy 判效果一般
> → v4「鎏金锋」草案⛔（未出图即否·**Eddy 定调：鼠标要简约·内部填充不要两种颜色·外深内浅即可**——金尖/形体影=设计过度·教训=简约件别加戏）
> → v5「简约双色锁」GPT prompt ⛔搁置（Eddy：AI 无法很好理解·转程序实现——简约几何件程序自产比出图可控）
> → v6 程序版转正（gen v3 尾腿顺斜方切）⛔ Eddy 复判：长方形拖尾仍怪·AI 和程序都不擅长这附肢→整条去掉
> → v6.1 去尾箭镞版（箭头外形 Eddy ✅通过·教训=细长附肢在 48px 档怎么做都别扭·经典箭镞已足够读作指针）
> → 悬停金身乘色⛔（Eddy：用深色表示悬停完全看不出来还误导→重设计）
> → v6.2 悬停手型⛔（Eddy：像竖着中指·保持箭头形·要么不变要么换动效但⛔变暗）
> → **v6.3 悬停金晕版（现役·2026-07-15 晚落位）**：gen_ui_cursor.gd v6=两态箭镞完全同形同色·
>   悬停只在描边外圈绽 1 设计格**金晕外环 #DCA12E**（全游戏点选同语言=道具格/图鉴选中金晕·深金档双衬底已验证·
>   变亮不变暗）·hotspot 两态同=描边尖端 (4,2)（金晕只占透明区=切换零跳动点击点不漂）·
>   像素自检 20 项 PASS（含金晕全包描边+两态描边/身像素集逐点一致）+预览截图目检过·GUT 376 绿·待 Eddy 亲审。
>   退路：悬停"什么都不变"=transition_manager 把 POINTING_HAND 注册指向 CURSOR_ARROW 一行即回。
> v3.1 贴图当前在位=占位（v4 出图后丢 `assets/import/鼠标箭头.png` 同名→重跑 tools/import_cursor_art.gd→--import 即换装·接线零改动）。
> 接线（已落位·不随出图变）：注册=transition_manager._ready（hotspot 按新图重量）；
> 悬停手型=button_juice 全线 POINTING_HAND；预览=tools/cursor_preview（⚠OS 指针不进截图·手感=Eddy F6）。

### ~~v5「简约双色锁·经典箭头」GPT prompt~~（⛔ 搁置·Eddy 转程序实现=v6 现役·本 prompt 留作备用溯源）

> v5 修正（2026-07-15 Eddy 否 v4：设计差·鼠标要**简约**·内部填充不要两种颜色·**外深内浅**即可）：
> 全图锁死两色=近黑描边 #130C08（外深·2 设计格）+暖纸身 #F0D7A2（内浅·单一平色）；
> ⛔金尖/⛔形体影/⛔任何第三色——加**双色铁锁段**+检查单明列"出现第三色即废"（防模型自作主张加装饰）。
> 与 v3.1 结构同源·实质差异=双色锁写死+描边统一 2 设计格。
> 悬停版=乘色派生照旧零改动（纸身 F0D7A2→暖金 D4A94E·近黑描边几乎不动）。

参考图 image1=`assets/ui/ui_nav_button.png`（取：近黑框族色+暖纸面色+像素笔感；弃：签牌形制/回纹钩/尺寸——同 v3.1 用法）。
落位管线照旧：出图→丢 `assets/import/鼠标箭头.png` 同名→重跑 tools/import_cursor_art.gd→--import→cursor_preview 双衬底目检→Eddy 实机 F6。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is the finalized navigation button plate from this game's
UI set — same family, painted by the same hand. From image 1 take ONLY its
color family (the near-black espresso of its dark frame, #130C08 family,
and the warm cream of its paper face, #F0D7A2 family) and its chunky
confident pixel stroke feel. IGNORE everything else about it: its plate
shape, its meander hook corners, its layout and size.

Subject: the mouse cursor for the same game — the universally recognized
CLASSIC ARROW cursor silhouette, the same shape every desktop arrow cursor
has: a straight vertical left edge, a straight diagonal right edge meeting
it at a needle-sharp tip pointing UPPER-LEFT, a neat notched heel, and one
short straight tail leg. Zero learning cost: anyone sees it and knows it
is the pointer. It is deliberately SIMPLE and clean.

Composition lock (CRITICAL): exactly ONE cursor, centered, filling about
80% of the canvas height, tip aimed at the upper-left corner. Straight-on
flat view, no perspective, no 3D, no rotation ambiguity.

This cursor has exactly THREE visible features. All three are REQUIRED:

Feature 1 — the tip: the upper-left point converges to a single crisp
pixel corner — this is the click point. No blunt or rounded tip.

Feature 2 — the two-color body (CRITICAL lock): the entire cursor uses
exactly TWO colors and nothing else — dark outside, light inside. The
ENTIRE silhouette carries an unbroken near-black espresso outline
(#130C08 family), 2 grid pixels thick; the whole interior is ONE single
flat warm cream paper fill (#F0D7A2 family). No gold, no second interior
tone, no shading step, no highlight, no texture — any third color
anywhere is a FAILURE. Bright warm body pops on dark night scenes; the
dark outline defines it on bright paper screens.

Feature 3 — the pixel craft: the diagonal edges show visible square pixel
staircase steps (retro JRPG feel). A smooth vector-clean arrow with no
visible pixel steps is a FAILURE.

Tail discipline (CRITICAL): the tail leg is ONE short straight stroke
ending in a clean square cut, aligned with the leg's own direction. NO
hook, NO bend, NO flick, NO curl, NO extra appendage of any kind at the
tail or heel. The silhouette contains nothing that is not part of the
classic arrow shape.

Even lighting: no glow, no halo, no drop shadow, no backdrop of any kind.

Small-size discipline (CRITICAL): designed on a strict 48×48 pixel grid —
final in-game size is about 40×56 px; every stroke at least 2 grid pixels
thick (the single-pixel tip is the only exception); no hairlines, no fine
filigree.

Final self-check — the image FAILS if ANY of these is true:
· the tip is blunt, rounded, or does not point to the upper-left;
· any third color appears anywhere — gold accents, interior shading,
  highlights, or a two-tone fill;
· the body is white, gray or cold instead of warm cream;
· the dark outline is missing or broken anywhere;
· any hook, bend, curl or appendage exists at the tail or heel;
· any gradient, anti-aliasing, dithering, glow or shadow appears;
· there is a second object, a backdrop, or any text in frame;
· the diagonal edges are smooth vector curves with no visible pixel
  staircase.

Output: one single cursor, centered, front view, flat, on a fully
transparent background (PNG with alpha).
```

### ~~v3.1「族语化经典箭头·暖色版」~~（⛔ 已否·溯源——2026-07-15 出图落位后 Eddy 判"效果一般"·病根见上沿革）

> v3.1 修订（Eddy 2026-07-15：**避免暗色作主色·改暖色**）：主体=暖纸身 #F0D7A2 + 近黑描边 #130C08
> （亮填充+暗轮廓=设计系统 §2 取色铁律——暗夜亮身跳出·亮纸暗轮廓勾形）；悬停版=身换暖金 #D4A94E。
> 程序占位（tools/gen_ui_cursor.gd）已同步暖色方案。

参考图 image1=`assets/art_src/ui/ui_nav_button.png`（取：近黑框族色+暖纸面色+像素笔感；弃：签牌形制/回纹钩/尺寸）。
悬停手型版=出图后**对话增量改**（附后）。落位管线：转透明→量边界→整数倍降采样 48×48→量尖端 hotspot→同路径替换→--import。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is the finalized navigation button plate from this game's
UI set — same family, painted by the same hand. From image 1 take ONLY its
color family (the near-black espresso of its dark frame, #130C08 family,
and the warm cream of its paper face, #F0D7A2 family) and its chunky
confident pixel stroke feel. IGNORE everything else about it: its plate
shape, its meander hook corners, its layout and size.

Subject: a single mouse cursor for the same game — the universally
recognized CLASSIC ARROW cursor silhouette, the same shape every desktop
arrow cursor has: a straight vertical left edge, a straight diagonal right
edge meeting at a needle-sharp tip pointing UPPER-LEFT, a notched heel, and
one short straight tail leg. Zero learning cost: anyone sees it and knows
it is the pointer.

Composition lock (CRITICAL): exactly ONE cursor, centered, filling about
80% of the canvas, tip aimed at the upper-left corner. Straight-on flat
view, no perspective, no 3D, no rotation ambiguity.

This cursor has exactly FOUR visible features. All four are REQUIRED:

Feature 1 — the tip: the upper-left point converges to a single crisp
pixel corner — this is the click point. No blunt or rounded tip.

Feature 2 — the body: filled warm cream paper tone (#F0D7A2 family), one
solid flat color, no gradient, no texture inside. The body must be LIGHT
and WARM — a dark-bodied arrow is a FAILURE.

Feature 3 — the rim: the ENTIRE silhouette carries a thin near-black
espresso outline (#130C08 family), 1-2 pixels thick and unbroken. Bright
warm body pops on dark night scenes; the dark outline defines it on
bright paper screens.

Feature 4 — the pixel craft: the diagonal edges show visible square pixel
staircase steps (retro JRPG feel). A smooth vector-clean arrow with no
visible pixel steps is a FAILURE.

Tail discipline (CRITICAL — this fixes the previous version): the tail leg
is ONE short straight stroke ending in a clean square cut, aligned with
the leg's own direction. NO hook, NO bend, NO flick, NO curl, NO extra
appendage of any kind at the tail or heel. The silhouette contains nothing
that is not part of the classic arrow shape.

Even lighting: no glow, no halo, no drop shadow, no backdrop of any kind.

Small-size discipline (CRITICAL): designed on a strict 48×48 pixel grid —
every stroke at least 2 grid pixels thick (the single-pixel tip is the
only exception); no hairlines, no fine filigree.

Final self-check — the image FAILS if ANY of these is true:
· the tip is blunt, rounded, or does not point to the upper-left;
· any hook, bend, curl or appendage exists at the tail or heel;
· the body is dark, cold, or gray instead of warm cream;
· the dark outline is missing or broken anywhere;
· any gradient, anti-aliasing, dithering, glow or shadow appears;
· there is a second object, a backdrop, or any text in frame;
· OR the opposite failure: a featureless smooth vector arrow with no
  visible pixel staircase — a sterile flat icon is JUST AS WRONG.

Output: one single cursor, centered, front view, flat, on a fully
transparent background (PNG with alpha).
```

**悬停手型版（出图过审后对话增量改·同轮廓同热点）**：

```text
Keep exactly this cursor — same silhouette, same tip, same proportions.
Only change the body fill from warm cream to warm gold (#D4A94E family).
The near-black outline stays unchanged, unbroken as before.
```

### ~~v1「如意云头小柄」~~（⛔ 已否·溯源）

设计（2026-07-14 Eddy 选 C）：斜置如意小柄——**左上尖端**（点击热点·必须收束到单像素尖）+右下**祥云头收尾**（tab_cloud 端头云卷同形制）；主体近黑浓缩咖啡+云头茶金+**全轮廓奶油描边 1-2px**（保证亮纸/夜景双衬底可见）。48×48 档。
形态规划：ARROW（本 prompt）+ POINTING_HAND（出图后**对话增量改**："Keep exactly this cursor; only tint the cloud head warm gold (#D4A94E family) and open its curls slightly. Same silhouette, same tip."·同轮廓同热点）+ IBEAM 首版用引擎默认。
参考图=`assets/art_src/ui/tab_cloud.png` 单参考（取：端头祥云卷形制；弃：横幅结构/金色/尺寸）。
落位管线：出图 1024×1024→转透明→量边界→整数倍降采样 48×48→量尖端像素=hotspot→开机入口 `Input.set_custom_mouse_cursor(tex, ARROW/POINTING_HAND, hotspot)`（零 project.godot 改动）。⚠ OS 指针不进视口截图：自检=预览探针把贴图按实寸画在亮纸/夜景衬底上；实机手感=Eddy F6。

```text
Style anchor: 2D game pixel art for an oriental fantasy game, hand-drawn
storybook warmth fused with retro pixel aesthetics. Crisp hard-edged square
pixels, no anti-aliasing, no blur, no dithering gradients. Warm top-down
neutral lighting, no cast shadows painted into the asset. Restrained
ornament: no gems, no rivet arrays, no heavy embossing. No text or lettering
anywhere. The asset is rendered alone on a fully transparent background
(PNG with alpha), nothing else in frame.

Attached image 1 is the finalized cloud-head tab banner from this game's UI
set — same family, painted by the same hand. From image 1 take ONLY the way
its two ends curl into round auspicious cloud heads (the spiral cloud
lobes). IGNORE everything else about it: its long banner shape, its gold
color, its size and horizontal layout.

Subject: a single mouse cursor for the same game — a tiny ruyi wand seen
diagonally: a slender pointed shaft whose sharp tip aims to the UPPER-LEFT,
and whose lower-right end blooms into a small auspicious cloud head in the
manner of image 1's end curls. It must read instantly as a game cursor:
one sharp point to click with, one decorative cloud tail.

Composition lock (CRITICAL): exactly ONE cursor, centered, filling about
80% of the canvas, its tip pointing toward the upper-left corner along a
45-degree diagonal. Straight-on flat view, no perspective, no 3D, no
rotation ambiguity.

This cursor has exactly THREE visible features. All three are REQUIRED:

Feature 1 — the shaft: a slender straight shaft running from the upper-left
tip to the lower-right, filled dark espresso (#1F1006 family). Toward the
upper-left it tapers needle-sharp: the final tip must converge to a single
crisp pixel corner — this is the click point. No blunt or rounded tip.

Feature 2 — the cloud head: at the lower-right end the shaft blooms into a
compact auspicious cloud head — two or three round curl lobes exactly in
the manner of image 1's end curls — filled warm tea (#F0D7A2 family) with
a dark espresso outline. Compact and chunky, not wispy.

Feature 3 — the rim: the ENTIRE cursor silhouette carries a thin warm
cream outer rim (#F3E4BC family), 1-2 pixels thick and unbroken, so the
cursor stays visible on both dark night scenes and bright paper screens.

Even lighting: no glow, no halo, no drop shadow, no backdrop of any kind.

Small-size discipline (CRITICAL): designed on a strict 48×48 pixel grid —
every stroke at least 2 grid pixels thick (the single-pixel tip is the
only exception); the cloud head fits within about 22×22 px; no hairline
curls, no fine filigree.

Pixel grid and size: strict 48×48 pixel grid; final in-game size 48×48 px.

Final self-check — the image FAILS if ANY of these is true:
· the tip is blunt, rounded, or does not point to the upper-left;
· the cloud head is missing, wispy, or has more than three lobes;
· the cream rim is missing or broken;
· there is any gold, red, glow, shadow, or a second object in frame;
· strokes thinner than 2 grid pixels appear anywhere except the tip.

Output: one single cursor, centered, front view, flat, on a fully
transparent background (PNG with alpha).
```

### 导航钮备选（v12 仍不合意再展开）

- **D 祥云托角式**：素签牌+一角同色系祥云（tab_cloud 族语）；柔和·风险=低对比下存在感不足。
- **E 界画双线式**：方角+双线+回字角、无端饰；比 v12 更收敛的退路。
- ~~B 横匾缩印式~~：**已由 v12 吸收**（直角+去骨缘=规避抢牌匾层级的原风险）。
- ⛔ 已排除：朱砂印/红点缀·卷轴复用（含滚轴/圆头帽）·金/金内圈·切角轮廓（=牌匾形制·v11 教训）·漂浮孤钩（=旧版同构）·素板。
