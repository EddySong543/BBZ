extends Control

## 道具图鉴 v5「实体典籍」（2026-07-04 Eddy 定向重做：跳出旧框架·书本外框入画）。
## 参考锚 = ref15（暗格衬亮页·图标弹跳）/ ref17（书=悬浮实体·页签书签化·悬挂牌匾）/ ref18（详情=钉在页上的卡片+划线手记）。
## 抓感觉不照抄：
##   · 书是一个「物件」浮在深靛夜色上（封皮包住页块·页厚台阶可见·金属护角）——不再是全屏铺满的"墙纸"。
##   · 三阶页签 = 从书右缘伸出的实体书签（选中抽出更长更亮）——不再是顶栏胶囊按钮。
##   · 标题 = 悬挂在书顶的牌匾；返回 = 夜色上的浮动羊皮芯片；顶栏整条删除。
##   · 左页 = 深炭格衬亮羊皮（彩色图标自己会跳）；右页 = 稀有度横幅 + 图标卡 + 划线手记。
## ⛔ 配色禁区（Eddy 2026-07-04）：暗红/棕全抛。（衬底沿革：深靛夜色 → 2026-07-13 宣纸淡墨山水贴图·
##   深靛做 UI 衬底已被整体否定=memory [[ui-backdrop-no-deep-indigo]]·牌匾深靛底属点缀件不在此列。）
## ⚠ 装饰 ColorRect 必须 mouse_filter=IGNORE（否则吞点击=返回/切阶失效·踩过坑）。
## 2026-07-14 三改（Eddy）：牌匾阴影贴形（矩形→贴图剪影）+ 选中重设计（金晕外环=战斗点选同语言）
##   + 右页排版重构（单列居中主轴·图标卡/辉光/手记划线退役）+ 返回钮换导航钮皮 + 左页大字水印退役。

const PLAQUE_TEX := preload("res://assets/ui/ui_plaque.png")                              # 悬挂牌匾(GPT 米色回纹匾·320×62·9-slice 边距 50/20·2026-07-13)
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")   # 格底：圆角+渐变（v5 中性深炭）
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")      # 选中金晕外环（与战斗道具栏点选同语言·2026-07-14）
const LEGENDARY_BG := preload("res://assets/ui/gold_bottom.png")                          # 传说道具金云纹格底(Eddy 美术)
const SCROLL_TEX := preload("res://assets/ui/item_codex_scroll.png")                      # 整屏手卷卷轴(GPT 出图·2026-07-13 二版·1672×941=16:9·棋盘格假透明已转真 alpha=img_checker_to_alpha)
const BACKDROP_TEX := preload("res://assets/ui/item_codex_backdrop.png")                  # 衬底=宣纸淡墨山水(GPT 出图·2026-07-13 Eddy 选 A 修订版·下缘远山+顶部一线远峰·中部留白)
const INK_CLOUDS_SHADER := preload("res://assets/shaders/canvas_ui_ink_clouds.gdshader")  # 衬底像素墨云旗 v2(上下环绕带·整像素步进流动·2026-07-13 重做)
const ITEM_FRAME_TEX := {   # 三阶回纹框(头像框素材同源换色·img_recolor·2026-07-13·三提亮="太灰"再进一档)
	1: preload("res://assets/ui/item_frame_t1.png"),   # 普通=亮青空蓝 #8FB8E4(78A2CE→再亮)
	2: preload("res://assets/ui/item_frame_t2.png"),   # 稀有=亮藕紫 #BFA0E8(A98BD8→再亮)
	3: preload("res://assets/ui/item_frame_t3.png"),   # 传说=亮鎏金 #F0C468(E4B75C→再亮)
}
const TAB_CLOUD_TEX := {   # 三阶祥云页签(GPT 双端云头横幅·240×56·img_recolor 同三阶色·2026-07-13)
	1: preload("res://assets/ui/tab_cloud_t1.png"),
	2: preload("res://assets/ui/tab_cloud_t2.png"),
	3: preload("res://assets/ui/tab_cloud_t3.png"),
}
const BANNER_TEX := preload("res://assets/ui/ui_banner_scroll.png")   # 道具名小卷轴横幅(GPT·224×45·轴杆+祥云端)
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")   # 返回钮=主菜单导航钮同皮(v12 回纹抱端签牌·2026-07-14 落位)
const NAV_PLATE_MARGIN_X := 22   # v14 净面(main_menu 同值)
const NAV_PLATE_MARGIN_Y := 20
const TIER_INK := {   # 道具名墨色三阶（压奶油纸·稀有度不再整条染横幅——2026-07-13 小卷轴换皮）
	1: Color("34608F"), 2: Color("6B3D96"), 3: Color("8F6A1E"),
}
const LEGENDARY_BG_TINT := Color(1.0, 1.0, 1.0, 1.0)                                       # 原图亮度·不做暗处理(Eddy 2026-06-27)
const MENU_SCENE := "res://src/ui/main_menu.tscn"

# （2026-07-14 死码清理：v5 书壳时代配色 GOLD_MID/GOLD_TEXT/IVORY/COVER*/PAGE*、
#   纸质感 PAPER_SHADER+_paper_mat 全退役——挂点已陆续换贴图资产，无引用。）

# ── 选中态（2026-07-14 重设计：旧 3px 金边 ColorRect 在亮三阶框上几乎不可见——
#    换战斗道具栏「点选」同语言=金晕外环+框身提亮·全游戏点选一个金）──
# ⚠ 亮度档随衬底走（实测教训）：战斗暗底=淡金 fff0a0 能读；图鉴亮纸上淡金≈隐形（就是旧版"极淡黄光"的死法）
#   → 亮纸语境用深饱和金（传说金 dca12e 同源）·外露带必须整条是金（外描边也走金·深咖在暗底读成黑圈）。
const GOLD_SEL := Color("dca12e")              # 金晕环主色（亮纸档·与稀有度传说金同源）
const RING_PAD := 6.0                          # 金晕外环外扩像素（战斗=4·图鉴格小+框带深描边吃掉视觉宽度→加到 6 才够跳）
const SEL_TINT := Color(1.18, 1.10, 0.98)      # 选中框身轻暖提亮（乘色不压蓝通道·防蓝框染绿·战斗定版同值）

# （2026-07-13 衬底换宣纸山水贴图：深靛 NIGHT_* 三常量与 _retint_background 退役——
#   背景图不透明满屏盖住 Background 节点·gallery_background.tscn 本体不动=英雄图鉴共用。）

const INK := Color(0.24, 0.19, 0.12)           # 墨（亮页主文字）
const INK_DIM := Color(0.48, 0.41, 0.28)       # 淡墨（次级/划线/注记）
# 格底方案（2026-07-13 Eddy 四改定版：格内整体【比外框深一档】——四角=深饱和阶色·中心=略浅阶色·
# 内外层次仍对齐传说 gold_bottom；⛔白圈版/比框亮版均被否——v5 深炭格退役）。
# 传说不走此表（格底=gold_bottom 金云纹美术·只换框色）。
const CELL_FILL := {1: Color("#6E9BD2"), 2: Color("#9A7FD0")}     # 四角=深饱和阶色（比框 8FB8E4/BFA0E8 深）
const CELL_CENTER := {1: Color("#88AEDE"), 2: Color("#B098E0")}   # 中心=略浅阶色（仍≤框亮度·层次感）

# 维度 → 语义色（与战斗动作按钮/抽卡同源·详情维度章用）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"), "中立": Color("8a8f98"),
	"博弈": Color("3f9a8f"), "趣味": Color("c86f8a"),
}
const DIM_FALLBACK := Color(0.42, 0.42, 0.47)

# 阶 → 稀有度色（普通蓝/稀有紫/传说金·Eddy 定）+ 标签。
const TIER_COLOR := {1: Color("4a7bc0"), 2: Color("8a4fc4"), 3: Color("dca12e")}
const TIER_LABEL := {1: "普通", 2: "稀有", 3: "传说"}

# ── 书本几何（书=居中实体·封皮包页块·夜色留边）──
const BOOK := Rect2(210, 96, 1500, 906)        # 封皮外框
const PAGE_L := Rect2(240, 128, 712, 842)      # 左页（网格）
const PAGE_R := Rect2(968, 128, 712, 842)      # 右页（详情）
const BANNER := Rect2(806, 46, 308, 78)        # 悬挂牌匾（压住书顶缘）
const TAB_W := 214.0                            # 祥云页签（2026-07-13 换皮：240×56 资产等比 4.28:1·原纸签 130×86）
const TAB_H := 50.0
const TAB_X := 1600.0                           # 收起时 x（右缘 1814≈右木轴内侧）
const TAB_PULL := 18.0                          # 选中抽出量
const TAB_Y0 := 236.0
const TAB_GAP := 112.0

# ── 左页网格（六列·当前阶最多 24 件=6×4）──
const COLS := 6
const BOX := 92.0        # 道具方框（正方·icon 居中其内）
const NAME_H := 34.0     # 框【外】下方名字带高
const CARD_W := BOX
const CARD_H := BOX + NAME_H
const STEP_X := 108.0
const ROW_H := 150.0
const X0 := 282.0
const ROW_Y0 := 236.0

var _tier: int = 1
var _items: Array[ItemData] = []
var _cards: Array[Button] = []
var _sel_idx: int = -1

var _book_layer: Control          # 书本实体（一次建好·不随切阶重建）
var _tab_btns: Array[Button] = []

# 详情板部件（_build_detail_panel 一次建好）
var _d_icon: TextureRect
var _d_icon_fallback: Label
var _d_cell_mat: ShaderMaterial     # 右页大图鉴格底材质（稀有度色/传说金底按选中件重设·2026-07-14）
var _d_frame: TextureRect           # 右页大回纹阶框（128 源 ×2=256 整数放大·2026-07-14）
var _d_name: Label
var _d_name_banner: NinePatchRect   # 小卷轴横幅（原双 ColorRect 稀有度色条退役·2026-07-13）
var _d_tier_edge: ColorRect
var _d_tier_fill: ColorRect
var _d_tier_lbl: Label
var _d_desc: Label
var _d_flavor: Label
var _d_pop_tween: Tween             # 右页图标落位微弹（快速方向键换件时先 kill 再建）
var _sel_tweens: Array[Tween] = []  # 选中动效 tween（pop+呼吸·换选先 kill 全部）

@onready var pool_area: Control = $PoolArea
@onready var detail_area: Control = $DetailArea
@onready var back_btn: Button = $TopBand/BackButton
@onready var title_lbl: Label = $TopBand/Title
@onready var count_lbl: Label = $TopBand/CountLabel


func _ready() -> void:
	_build_book()
	_setup_top()
	_build_detail_panel()
	_select_tier(1)
	_play_intro()


# ============================================================
# 卷轴实体（2026-07-13 换皮：整屏手卷贴图替换程序化书壳·GPT 出图·
#   同日二版：衬底换宣纸淡墨山水贴图，深靛夜色退役）
#   旧书壳（封皮/页块台阶/双页/中缝/护角）全部退役——纸面/木轴/云纹/描边都在贴图里。
# ============================================================

func _build_book() -> void:
	# 战斗内嵌模式（Eddy 2026-07-13）：不带任何背景——卷轴直接悬在浮层暗幕上。
	# （embedded_close 由 battle_codex_overlay 在 add_child 前注入 → _ready 时已可判。）
	var embedded := embedded_close.is_valid()
	if embedded:
		var bg := get_node_or_null("Background") as Control
		if bg != null:
			bg.visible = false
	else:
		# 衬底=宣纸淡墨山水（Eddy 选 A 修订版：GPT 静态图+像素墨云动效·仅主菜单直开挂）。
		# ⚠ 独立静态层，不进 _book_layer——入场动画整层上浮+淡入，背景不该跟着飞。
		# 木桌 shader 留档 assets/shaders/canvas_ui_wood_desk.gdshader（旧 B 方案·未挂）。
		var backdrop := TextureRect.new()
		backdrop.name = "Backdrop"
		backdrop.texture = BACKDROP_TEX
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 软笔触画面非像素资产·NEAREST 拉伸会出格纹
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		backdrop.position = Vector2.ZERO
		backdrop.size = Vector2(1920.0, 1080.0)   # ⚠ 锚点满铺在程序容器下会塌 0，必须显式尺寸
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
		move_child(backdrop, 1)   # Background 之上（不透明满屏=深靛夜色被整层盖住）

		# 像素墨云带 v2.1 连绵态：上下环绕（衬底之上、卷轴之下·各掖 40px 进纸缘后面）。
		# 参考战斗 dark_smoke 稳定骨架·长云搭接成起伏带（Eddy：孤立云朵慢+卡→连绵持续流动）。
		# ⚠ 两条横带 quad 非全屏（全屏程序化 shader 性能黑洞教训）。
		_add_ink_cloud_band(Rect2(0, 0, 1920, 150), 0.37, 0.0, 0.03, 2)      # 顶带：≈7px/s 整层平滑滑移(v2.2·非步进)
		_add_ink_cloud_band(Rect2(0, 930, 1920, 150), 0.63, 5.0, -0.025, 3)  # 底带：反向≈6px/s

	_book_layer = Control.new()
	_book_layer.name = "BookLayer"
	_book_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book_layer)
	move_child(_book_layer, 1 if embedded else 4)   # 内嵌=Background 位·直开=压衬底+云气之上

	# 整屏卷轴（1672×941 原生 16:9 → 拉伸满屏 ×1.148·NEAREST 保像素边·
	# 「大小优先于严格完美像素」项目惯例）。二版实测（img_checker_to_alpha 报告换算）：
	# 木轴内侧=纸面 x≈113-1808（与旧版几乎一致·横向布局不动），纸面纵向 y≈110-970（旧 60-1020）。
	var scroll := TextureRect.new()
	scroll.name = "Scroll"
	scroll.texture = SCROLL_TEX
	scroll.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode = TextureRect.STRETCH_SCALE
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(1920.0, 1080.0)   # ⚠ _book_layer 是零尺寸 Control——锚点满铺会塌 0，必须显式尺寸
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_layer.add_child(scroll)

	# 三阶书签页签（纸面右缘·贴木轴内侧）
	_build_bookmark_tabs()


## 像素墨云横带（衬底装饰·shader=canvas_ui_ink_clouds v2）。
## center_frac=云带垂直中心（带高比例）；seed_v=层种子（⚠上下带必须互异）；flow=流速（格/秒·负=反向）。
func _add_ink_cloud_band(r: Rect2, center_frac: float, seed_v: float, flow: float, tree_idx: int) -> void:
	var band := ColorRect.new()
	band.name = "InkCloudsTop" if r.position.y < 540.0 else "InkCloudsBottom"
	band.color = Color.WHITE           # shader 乘 COLOR·须白（跟随 modulate 惯例）
	band.position = r.position
	band.size = r.size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 装饰件必 IGNORE（吞点击踩过坑）
	var m := ShaderMaterial.new()
	m.shader = INK_CLOUDS_SHADER
	m.set_shader_parameter("center_frac", center_frac)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("flow_speed", flow)
	band.material = m
	add_child(band)
	move_child(band, tree_idx)


## 三阶页签=祥云签（2026-07-13 换皮：GPT 双端云头横幅·三阶同源换色——纸签+稀有度端带+描边全退役）。
func _build_bookmark_tabs() -> void:
	for i in 3:
		var t := i + 1
		var btn := Button.new()
		btn.name = "BookmarkTab%d" % t
		btn.position = Vector2(TAB_X, TAB_Y0 + i * TAB_GAP)
		btn.size = Vector2(TAB_W, TAB_H)
		btn.focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		FontManager.apply_btn(btn, 22)
		btn.text = tr(String(TIER_LABEL[t]))
		var cloud := TextureRect.new()       # 祥云身（阶色贴图·选中提亮走 _refresh_tabs）
		cloud.name = "Cloud"
		cloud.texture = TAB_CLOUD_TEX[t]
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.show_behind_parent = true      # 垫到按钮文字之下
		cloud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cloud)
		btn.pressed.connect(_select_tier.bind(t))
		var bj := ButtonJuice.new()
		bj.name = "ButtonJuice"
		btn.add_child(bj)
		_book_layer.add_child(btn)
		_tab_btns.append(btn)


## 刷新页签选中态：选中=抽出+云身原亮+墨字；未选=收进+云身压暗+淡墨字。
func _refresh_tabs() -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		var sel := (i + 1) == _tier
		var cloud := btn.get_node("Cloud") as TextureRect
		cloud.modulate = Color.WHITE if sel else Color(0.74, 0.72, 0.68)
		btn.add_theme_color_override("font_color", INK if sel else Color(INK, 0.55))
		var tx := TAB_X + (TAB_PULL if sel else 0.0)
		create_tween().tween_property(btn, "position:x", tx, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ============================================================
# 顶部浮动件：悬挂牌匾 + 返回芯片 + 计数注记
# ============================================================

func _setup_top() -> void:
	_build_banner()
	_style_back_button()
	# 计数=左页章头行右端的墨水注记（与章头同行·像书页页眉）
	FontManager.apply(count_lbl, 18)
	count_lbl.add_theme_color_override("font_color", Color(INK_DIM, 0.9))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.position = Vector2(714, 164)
	count_lbl.size = Vector2(200, 26)


## 悬挂牌匾（2026-07-13 换皮：GPT 米色回纹匾 9-slice+墨字——深靛底+shader 金框+泥金字退役）。
func _build_banner() -> void:
	var band := $TopBand as Control
	# 贴形投影（2026-07-14 Eddy：矩形投影与匾形不匹配）：牌匾贴图自身当剪影——
	# 同 9-slice 同尺寸偏移一份·modulate 乘暗=轮廓/透明区完全跟形（引擎加·不画进资产）。
	var shadow := NinePatchRect.new()
	shadow.name = "PlaqueShadow"
	shadow.texture = PLAQUE_TEX
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.patch_margin_left = 50
	shadow.patch_margin_right = 50
	shadow.patch_margin_top = 20
	shadow.patch_margin_bottom = 20
	shadow.position = BANNER.position + Vector2(6, 8)
	shadow.size = BANNER.size
	shadow.modulate = Color(0.10, 0.07, 0.05, 0.38)   # 暖黑剪影（与宣纸暖底同温·⛔冷藏青）
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(shadow)
	var plaque := NinePatchRect.new()
	plaque.name = "Plaque"
	plaque.texture = PLAQUE_TEX
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque.patch_margin_left = 50    # 回纹角区≈48px·9-slice 四角原比例中段拉伸（三挂点比例不一）
	plaque.patch_margin_right = 50
	plaque.patch_margin_top = 20
	plaque.patch_margin_bottom = 20
	plaque.position = BANNER.position
	plaque.size = BANNER.size
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(plaque)
	title_lbl.text = tr("道具图鉴")
	title_lbl.position = BANNER.position + Vector2(0, -4)
	title_lbl.size = BANNER.size
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.z_index = 1
	FontManager.apply(title_lbl, 36)
	title_lbl.add_theme_color_override("font_color", INK)   # 匾面米色→墨字（亮面金字读不清）
	title_lbl.add_theme_constant_override("outline_size", 0)


func _style_back_button() -> void:
	FontManager.apply_btn(back_btn, 24)
	back_btn.add_theme_color_override("font_color", INK)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		back_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	# 2026-07-14 排版重构：灰白羊皮芯片退役→主菜单导航钮同皮（回纹钩 9-slice·全游戏导航一个语言）。
	var plate := NinePatchRect.new()
	plate.name = "Plate"
	plate.texture = NAV_PLATE_TEX
	plate.patch_margin_left = NAV_PLATE_MARGIN_X
	plate.patch_margin_right = NAV_PLATE_MARGIN_X
	plate.patch_margin_top = NAV_PLATE_MARGIN_Y
	plate.patch_margin_bottom = NAV_PLATE_MARGIN_Y
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.show_behind_parent = true
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击（返回失效）
	back_btn.add_child(plate)
	back_btn.pressed.connect(_back_to_menu)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	back_btn.add_child(bj)


func _rect(parent: Control, r: Rect2, col: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = col
	rect.position = r.position
	rect.size = r.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


# ============================================================
# 左页网格：按阶重建
# ============================================================

## 切换到某一阶：刷书签 + 重建网格 + 选中第 0 件。
func _select_tier(t: int) -> void:
	_tier = t
	_refresh_tabs()
	_items = ItemCatalog.all_for_tier(t)
	_sel_idx = -1
	_build_pool()
	count_lbl.text = tr("本页 %d 件") % _items.size()
	if not _items.is_empty():
		_select(0)


func _build_pool() -> void:
	for c in pool_area.get_children():
		c.queue_free()
	_cards.clear()
	# （2026-07-14 排版重构：章名大字水印退役——压在第 3/4 行卡名底下=乱源·阶名已有章头+页签双表达。）
	# 章头（ref15 的页首题字感）：阶名墨字 + 细墨线（计数注记在同行右端·见 _setup_top）
	var chapter := Label.new()
	chapter.text = tr(String(TIER_LABEL[_tier]))
	chapter.position = Vector2(X0, 150)
	chapter.size = Vector2(300, 40)
	FontManager.apply(chapter, 26)
	chapter.add_theme_color_override("font_color", INK)
	chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(chapter)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.30)
	rule.position = Vector2(X0, 198)
	rule.size = Vector2(632, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_area.add_child(rule)
	for i in _items.size():
		var card := _make_item_card(_items[i], i)
		card.position = Vector2(X0 + (i % COLS) * STEP_X, ROW_Y0 + floorf(i / float(COLS)) * ROW_H)
		pool_area.add_child(card)
		_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 单件道具卡（深炭格衬亮页·回纹阶框=蓝/紫/金·图标自己跳）。选中=金框由 _select 刷。
func _make_item_card(item: ItemData, idx: int) -> Button:
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.size = Vector2(CARD_W, CARD_H)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	# 选中金晕外环（2026-07-14 重设计·与战斗点选同源同参）：pixel_frame 金环外扩 4px·
	# 衬在回纹框后（框永不清除/不换色相）·常态隐藏·_select 切显隐+pop+呼吸。
	var ring := ColorRect.new()
	ring.name = "SelRing"
	ring.color = Color.WHITE
	ring.position = Vector2(-RING_PAD, -RING_PAD)
	ring.size = Vector2(BOX + RING_PAD * 2.0, BOX + RING_PAD * 2.0)
	var rm := ShaderMaterial.new()
	rm.shader = FRAME_SHADER
	rm.set_shader_parameter("edge_outer", GOLD_SEL.darkened(0.1))    # 外露 4px 就是这层——必须整条是金
	rm.set_shader_parameter("edge_mid", GOLD_SEL)
	rm.set_shader_parameter("edge_inner", GOLD_SEL.darkened(0.5))
	rm.set_shader_parameter("pixel_grid", (BOX + RING_PAD * 2.0) / 6.0)   # 像素粒径≈6px·与格底/战斗同比
	rm.set_shader_parameter("border_px", 2.0)
	rm.set_shader_parameter("noise_amt", 0.05)
	rm.set_shader_parameter("light_amount", 0.18)
	rm.set_shader_parameter("aspect", 1.0)
	rm.set_shader_parameter("corner_radius", 0.18)
	ring.material = rm
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	card.add_child(ring)
	# 格底：深炭中性格（ref15——亮页上的暗格·彩色图标自己跳）；传说铺金云纹美术。
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.position = Vector2.ZERO
	cell.size = Vector2(BOX, BOX)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = CELL_BG_SHADER
	cm.set_shader_parameter("fill_color", CELL_FILL.get(item.tier, CELL_FILL[1]))
	cm.set_shader_parameter("inner_color", CELL_CENTER.get(item.tier, CELL_CENTER[1]))
	cm.set_shader_parameter("center_glow", 1.0)
	cm.set_shader_parameter("corner_radius", 0.18)
	cm.set_shader_parameter("pixel_grid", BOX / 6.0)
	if item.tier == 3:
		cm.set_shader_parameter("use_tex", 1.0)
		cm.set_shader_parameter("bg_tex", LEGENDARY_BG)
		cm.set_shader_parameter("tex_tint", LEGENDARY_BG_TINT)
	cm.set_shader_parameter("cloud_on", 0.0)
	cell.material = cm
	card.add_child(cell)
	# 回纹阶框（2026-07-13 换皮：头像框素材同源换色三阶变体·原稀有度像素框 shader 退役）
	var frame := TextureRect.new()
	frame.name = "Frame"   # 选中提亮要取（2026-07-14）
	frame.texture = ITEM_FRAME_TEX[item.tier]
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.position = Vector2.ZERO
	frame.size = Vector2(BOX, BOX)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	# 图标（居中于暗格）
	var tex: Texture2D = ItemCatalog.load_icon(item.item_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		var isz := 70.0
		icon.position = Vector2((BOX - isz) * 0.5, (BOX - isz) * 0.5)
		icon.size = Vector2(isz, isz)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	# 名字（框外下方·亮页墨字直读）
	var name_lbl := Label.new()
	name_lbl.text = tr(item.item_name)
	name_lbl.position = Vector2(-12.0, BOX + 2.0)
	name_lbl.size = Vector2(BOX + 24.0, NAME_H)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", INK)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)
	card.pressed.connect(_select.bind(idx))
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	card.add_child(bj)
	return card


# ============================================================
# 右页：单列居中主轴（2026-07-14 排版重构·Eddy：旧版混乱不美观·要简约一目了然）
#   ①名字小卷轴 → ②大号图鉴格（=左页格同语言 2× 放大） → ③阶章 → ④一条分隔墨线 → ⑤描述 → ⑥风味
#   退役：页内四边细饰框 / 纸面图标卡+偏移投影+墨线框 / 径向暖辉光 / 三条手记划线（与文字错位=乱源）
# ============================================================

func _build_detail_panel() -> void:
	var px := PAGE_R.position.x
	var py := PAGE_R.position.y

	# ── ① 道具名横幅=小卷轴（GPT 贴图·2026-07-13 换皮）：横向 9-slice（轴杆+祥云端固定·纸面平铺）；
	#    竖向不切原生高（切了祥云会拉花）。稀有度改走道具名墨色三阶（TIER_INK·横幅不再染色）。
	_d_name_banner = NinePatchRect.new()
	_d_name_banner.texture = BANNER_TEX
	_d_name_banner.patch_margin_left = 96    # 轴杆 26 + 祥云端 ~66（固定不拉伸）
	_d_name_banner.patch_margin_right = 96
	_d_name_banner.patch_margin_top = 0      # 竖向原生高·不切
	_d_name_banner.patch_margin_bottom = 0
	_d_name_banner.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE   # 纸面平铺防颗粒拉伸
	_d_name_banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_name_banner.position = Vector2(px + 54, py + 72)
	_d_name_banner.size = Vector2(PAGE_R.size.x - 108, 45)
	_d_name_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_name_banner)
	_d_name = _make_label(Vector2(px + 57, py + 72), Vector2(PAGE_R.size.x - 114, 45), 32, TIER_INK[1])
	_d_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# ── ② 大号图鉴格：与左页格完全同语言（格底 shader+回纹阶框贴图）·128px 框源 ×2=256 整数放大保像素 ──
	var cell_r := Rect2(px + (PAGE_R.size.x - 256.0) * 0.5, py + 164, 256.0, 256.0)
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.position = cell_r.position
	cell.size = cell_r.size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_d_cell_mat = ShaderMaterial.new()
	_d_cell_mat.shader = CELL_BG_SHADER
	_d_cell_mat.set_shader_parameter("fill_color", CELL_FILL[1])
	_d_cell_mat.set_shader_parameter("inner_color", CELL_CENTER[1])
	_d_cell_mat.set_shader_parameter("center_glow", 1.0)
	_d_cell_mat.set_shader_parameter("corner_radius", 0.18)
	_d_cell_mat.set_shader_parameter("pixel_grid", 256.0 / 6.0)   # 像素粒径 6px=与左页格同比
	_d_cell_mat.set_shader_parameter("cloud_on", 0.0)
	_d_cell_mat.set_shader_parameter("bg_tex", LEGENDARY_BG)      # 传说金底常驻·use_tex 按选中件切
	_d_cell_mat.set_shader_parameter("tex_tint", LEGENDARY_BG_TINT)
	cell.material = _d_cell_mat
	detail_area.add_child(cell)
	_d_frame = TextureRect.new()
	_d_frame.texture = ITEM_FRAME_TEX[1]
	_d_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_frame.position = cell_r.position
	_d_frame.size = cell_r.size
	_d_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_frame)

	# 放大图标（居中比例与左页格同源：70/92 ≈ 192/256）
	_d_icon = TextureRect.new()
	_d_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_d_icon.size = Vector2(192, 192)
	_d_icon.position = cell_r.position + (cell_r.size - _d_icon.size) * 0.5
	_d_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(_d_icon)
	_d_icon_fallback = _make_label(cell_r.position, cell_r.size, 48, Color(INK, 0.6))
	_d_icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_d_icon_fallback.visible = false

	# ── ③ 阶章（居中药丸·紧跟大格）──
	_d_tier_edge = _chip_rect(Color(INK, 0.75))
	_d_tier_fill = _chip_rect(TIER_COLOR[1])
	_d_tier_lbl = _make_label(Vector2.ZERO, Vector2(120, 36), 18, Color.WHITE)
	_d_tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_text_outline(_d_tier_lbl)

	# ── ④ 一条分隔墨线（替代三条错位手记线）──
	_rect(detail_area, Rect2(px + (PAGE_R.size.x - 360.0) * 0.5, py + 532, 360, 1), Color(INK, 0.25))

	# ── ⑤ 描述（24px 墨字·定宽居中·Ark 整数档 2×12）+ ⑥ 风味淡墨 ──
	_d_desc = _make_label(
		Vector2(px + 76, py + 560),
		Vector2(PAGE_R.size.x - 152, 168), 24, INK)
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d_flavor = _make_label(
		Vector2(px + 76, py + 700),
		Vector2(PAGE_R.size.x - 152, 96), 16, Color(INK_DIM, 0.95))   # 最长描述 3 行止于 +662·风味贴着接（不孤儿化）
	_d_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_flavor.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_d_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 快捷键提示：卷轴下方·宣纸衬底上的墨字注记（二版纸底缘≈970 → y986 落在衬底山水留白带）
	var hint := _make_label(Vector2(0, 986), Vector2(1920, 24), 14, Color(INK, 0.62))
	hint.text = tr("← → 切换道具 · 普通/稀有/传说 切阶 · ESC 返回")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chip_rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(r)
	return r


## 章内白字补深描边 → 在金/蓝/紫任何饱和底色上都读得清。
func _chip_text_outline(lbl: Label) -> void:
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.9))


## 选中某件道具：左卡金晕外环+框身提亮（战斗点选同语言）+ 右页填充（大格/图标/阶章/描述）。
func _select(idx: int) -> void:
	if idx < 0 or idx >= _items.size():
		return
	if _sel_idx == idx:
		return
	for tw: Tween in _sel_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_sel_tweens.clear()
	if _sel_idx >= 0 and _sel_idx < _cards.size():
		var old := _cards[_sel_idx]
		var old_ring := old.get_node("SelRing") as ColorRect
		old_ring.visible = false
		old_ring.modulate = Color.WHITE
		(old.get_node("Frame") as TextureRect).modulate = Color.WHITE
	_sel_idx = idx
	_play_select_fx(_cards[idx])

	var it := _items[idx]
	var rc: Color = TIER_COLOR[it.tier]
	var tex: Texture2D = ItemCatalog.load_icon(it.item_id)
	if tex != null:
		_d_icon.texture = tex
		_d_icon.visible = true
		_d_icon_fallback.visible = false
	else:
		_d_icon.visible = false
		_d_icon_fallback.text = tr(it.item_name)
		_d_icon_fallback.visible = true
	# 右页大格跟随稀有度（材质持久·三参数每次重设：普通/稀有=色对·传说=金底图）
	_d_frame.texture = ITEM_FRAME_TEX[it.tier]
	_d_cell_mat.set_shader_parameter("fill_color", CELL_FILL.get(it.tier, CELL_FILL[1]))
	_d_cell_mat.set_shader_parameter("inner_color", CELL_CENTER.get(it.tier, CELL_CENTER[1]))
	_d_cell_mat.set_shader_parameter("use_tex", 1.0 if it.tier == 3 else 0.0)
	# 图标落位微弹（0.12s·换件时右页也有反馈·快速方向键连按先 kill）
	if _d_pop_tween != null and _d_pop_tween.is_valid():
		_d_pop_tween.kill()
	_d_icon.pivot_offset = _d_icon.size * 0.5
	_d_icon.scale = Vector2(1.06, 1.06)
	_d_pop_tween = create_tween()
	_d_pop_tween.tween_property(_d_icon, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_d_name.text = tr(it.item_name)
	_d_name.add_theme_color_override("font_color", TIER_INK[it.tier])   # 稀有度=名字墨色（横幅不染）
	_d_tier_lbl.text = tr(String(TIER_LABEL[it.tier]))
	_d_tier_fill.color = rc
	_d_desc.text = tr(it.description)
	_d_flavor.text = tr(it.flavor)
	_layout_chips()


## 选中动效（2026-07-14 重设计）：金晕环收拢 pop（0.14s·战斗同参）→ 安静呼吸（2.6s 循环·
## 在 24 格网格里"找得到"但不吵——图鉴动效拨杆=低）。框身提亮即时生效。
func _play_select_fx(card: Button) -> void:
	var ring := card.get_node("SelRing") as ColorRect
	(card.get_node("Frame") as TextureRect).modulate = SEL_TINT
	var end_pos := Vector2(-RING_PAD, -RING_PAD)
	var end_size := Vector2(BOX + RING_PAD * 2.0, BOX + RING_PAD * 2.0)
	ring.visible = true
	ring.position = end_pos - Vector2(3, 3)
	ring.size = end_size + Vector2(6, 6)
	ring.modulate = Color(1, 1, 1, 0.0)
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(ring, "position", end_pos, 0.14)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(ring, "size", end_size, 0.14)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(ring, "modulate:a", 1.0, 0.12)
	_sel_tweens.append(pop)
	var breath := create_tween()   # 首步 interval=让过 pop（两条 tween 不同时碰 modulate:a）
	breath.set_loops()
	breath.tween_interval(0.5)
	breath.tween_property(ring, "modulate:a", 0.85, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(ring, "modulate:a", 1.0, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sel_tweens.append(breath)


## 阶章在页内水平居中（章宽随文字 → 每次按内容重排）。
## 维度章不对玩家展示（内部设计分类·含设计术语·Eddy 2026-06-30）。
func _layout_chips() -> void:
	var y0: float = PAGE_R.position.y + 452   # 2026-07-14 重排：紧跟 256 大格（164+256+32）
	var f: Font = _d_tier_lbl.get_theme_font("font")
	var fs: int = _d_tier_lbl.get_theme_font_size("font_size")
	var w1: float = f.get_string_size(_d_tier_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 40.0
	var x0: float = PAGE_R.position.x + (PAGE_R.size.x - w1) * 0.5
	_d_tier_edge.position = Vector2(x0, y0)
	_d_tier_edge.size = Vector2(w1, 38)
	_d_tier_fill.position = Vector2(x0 + 1, y0 + 1)
	_d_tier_fill.size = Vector2(w1 - 2, 36)
	_d_tier_lbl.position = Vector2(x0, y0)
	_d_tier_lbl.size = Vector2(w1, 38)


# ============================================================
# 输入 / 转场 / 入场
# ============================================================

## ←/→ 环绕换道具，↑/↓ ±一行；ESC 回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
		get_viewport().set_input_as_handled()
		return
	var step := 0
	if event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("ui_up"):
		step = -COLS
	elif event.is_action_pressed("ui_down"):
		step = COLS
	if step != 0 and _sel_idx >= 0 and not _items.is_empty():
		_select(wrapi(_sel_idx + step, 0, _items.size()))
		get_viewport().set_input_as_handled()


## 战斗内嵌模式（battle_codex_overlay 注入）：有效时「返回/ESC」改走关闭浮层，不切场景。
var embedded_close: Callable = Callable()


func _back_to_menu() -> void:
	if embedded_close.is_valid():
		embedded_close.call()
		return
	TransitionManager.transition_to(MENU_SCENE)


## 入场：牌匾/返回滑入 + 书轻微上浮 + 左页卡按行翻开扫过 + 右页淡入。
func _play_intro() -> void:
	var band := $TopBand as Control
	var band_home := band.position
	band.position.y -= 130.0
	create_tween().tween_property(band, "position", band_home, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_book_layer.position.y += 26.0
	_book_layer.modulate.a = 0.0
	var tb := create_tween()
	tb.set_parallel(true)
	tb.tween_property(_book_layer, "position:y", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tb.tween_property(_book_layer, "modulate:a", 1.0, 0.25)
	for i in _cards.size():
		var card := _cards[i]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.001, 1.0)
		card.modulate.a = 0.0
		var delay := 0.1 + floorf(i / float(COLS)) * 0.1 + (i % COLS) * 0.03
		var ta := create_tween()
		ta.tween_interval(delay)
		ta.tween_property(card, "modulate:a", 1.0, 0.1)
		var tp := create_tween()
		tp.tween_interval(delay)
		tp.tween_property(card, "scale:x", 1.0, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	detail_area.modulate.a = 0.0
	var td := create_tween()
	td.tween_interval(0.25)
	td.tween_property(detail_area, "modulate:a", 1.0, 0.35)


# ============================================================
# 自绘部件
# ============================================================

func _make_label(pos: Vector2, sz: Vector2, font_px: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = sz
	FontManager.apply(lbl, font_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_area.add_child(lbl)
	return lbl
