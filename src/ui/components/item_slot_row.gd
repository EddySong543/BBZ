class_name ItemSlotRow
extends Control

## 道具栏组件（M2 显示 + M3 交互 + C 升级 + 配色重审 2026-06-20）：横排 3 个圆角 jelly 芯片。
## 芯片 = 复用动作按钮同款 canvas_button_jelly（圆角果冻·像素质感），按【状态/维度】分色、与按钮同色语言：
##   安静默认（锁=灰 / 空=暗格）→ 就绪点亮（维度色满铺：进攻红/防御蓝… + 金色高光边 + 升角标）。
##   原则「框安静、内容响」。interactive=true（P1）每槽可点击发 slot_clicked；false（P2·AI 道具-blind）仅显示、不点亮。
## ⚠ 行位置由 battle_screen 控（P1 贴左 / P2 镜像右贴）；道具名为占位文字，待换图标。
## 用法：add_child → interactive/connect（仅 P1）→ 每次 _update_all 调 refresh(battle, player, staged)。

signal slot_clicked(slot: int)
signal slot_upgrade_clicked(slot: int)   # 点击就绪可升级槽右上角「升」角标（C·升级线）

const SLOT_W := 68.0   # 道具框（2026-06-28 Eddy：76→缩小一些）
const SLOT_H := 68.0
const GAP := 9.0

## 维度 → 芯片底色（与动作按钮 / draft 卡 / 飘字同源的语义色板）。
const DIM_COLOR := {
	"进攻": Color("b8402f"), "防御": Color("3f6fb0"), "能量": Color("d2a32a"),
	"节奏": Color("c47f33"), "状态": Color("4f9d52"), "干扰": Color("6f5bb0"),
	"导出": Color("5f8a9a"), "随机": Color("8a8f98"),
}

## 道具框形式（2026-06-28 Eddy：战斗道具栏统一为「道具图鉴」同款形式）：
##   双层 = 暗格底 canvas_ui_item_cell_bg（稀有度暗底 + 中心高亮 + 传说金底图）+ 稀有度像素框 canvas_ui_pixel_frame。
##   与 item_gallery_screen 完全同源（像素框 + 暗格 + 居中图标 + 全圆角）。jelly 仅保留给右上「升」角标。
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")        # 稀有度像素框（同图鉴/英雄卡）
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")     # 暗格底：圆角 + 稀有度暗底 + 中心高亮 + 传说金底图
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")          # 仅「升」角标用
const LEGENDARY_BG := preload("res://assets/ui/gold_bottom.png")                            # 传说道具金云纹背景（Eddy 美术·与图鉴同源）
const LEGENDARY_BG_TINT := Color(1.0, 1.0, 1.0, 1.0)
const FRAME_EDGE_OUTER := Color(0.16, 0.10, 0.06)   # 框外轮廓=深咖（与图鉴同）
const CELL_CORNER := 0.18                            # 圆角（格底与框一致·与图鉴同·全圆角无方角）
const CELL_GRID := 23.0    # 像素格数（= 图鉴 BOX/6）。用「格数」而非 SLOT_W/6 → 边框按比例随框缩放、不会在小框上变粗（2026-06-28 Eddy：去掉过厚棕边·与图鉴完全一致）
const EDGE_OUTER := Color(0.11, 0.09, 0.075)    # 统一暗轮廓（暖黑·与暖色UI同温·任何色相都干净）
const GOLD_READY := Color("ffd86a")             # 道具本回合可用（interactive）→ 亮金高光边
const GOLD_STAGED := Color("fff0a0")            # 已点选使用 → 更亮金边
const GOLD_OPEN := Color("d8b85a")              # 可开 / 可抽 / 可补 → 提示金边（较暗·次级）
# 中性态填充（锁 / 待操作 / 空格）。2026-06-28：原冷暗灰 → 暖石色 + 整体提亮，与暖色动作按钮同温、不再显暗。
const SEAL_FT := Color(0.51, 0.46, 0.38)        # 锁：暖石灰（上）·2026-06-28 再提亮一档
const SEAL_FB := Color(0.36, 0.32, 0.26)
const SEAL_EI := Color(0.63, 0.57, 0.46)
const NEU_FT := Color(0.54, 0.49, 0.40)         # 待操作：暖石（上）
const NEU_FB := Color(0.39, 0.35, 0.28)
const NEU_EI := Color(0.66, 0.60, 0.48)
const EMP_FT := Color(0.31, 0.28, 0.23)         # 空格：暖石褐（非近黑冷）
const EMP_FB := Color(0.21, 0.19, 0.15)
const EMP_EI := Color(0.44, 0.40, 0.32)
# 无道具态（空/未解锁/不可操作）框色：去饱和中性灰（2026-06-28 Eddy：去掉"木色"边框；有道具一律走稀有度色）。
const EMPTY_EDGE := Color(0.43, 0.42, 0.41)
# 文字层级（2026-07-08 优化点②）：静默态文字退后、可操作态文字响——「框安静、内容响」延伸到字。
const TXT_BRIGHT := Color(0.98, 0.96, 0.9)      # 可抽/可补/就绪/✓用（可操作·亮米白）
const TXT_DIM := Color(0.78, 0.74, 0.66)        # 锁/待抽/锁中（静默电报·暖灰退后）
const TXT_FAINT := Color(0.62, 0.58, 0.50)      # 空格（最弱）

## interactive：本地玩家行可点击。setter 立即把按钮 mouse_filter 设为 STOP；P2（false）→ IGNORE。
var interactive := false:
	set(v):
		interactive = v
		for b in _buttons:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

const ICON_INSET := 9.0                          # 图标内缩（露出框·与图鉴 17/138≈12% 同比例·落在内框里不溢出）

var _cells: Array[ColorRect] = []              # 每槽暗格底（cell_bg：稀有度暗底 + 中心高亮 + 传说金底图）
var _cell_mats: Array[ShaderMaterial] = []     # refresh 重设 fill_color / center_glow / use_tex
var _frames: Array[ColorRect] = []             # 每槽稀有度像素框（pixel_frame）
var _frame_mats: Array[ShaderMaterial] = []    # refresh 重设 edge_mid / edge_inner（状态/稀有度色）
var _icons: Array[TextureRect] = []            # 道具图标层（缺图隐藏 → 回退文字·零回归）
var _icon_cache := {}                          # id → Texture2D / null（避免每帧 load/exists）
var _labels: Array[Label] = []
var _buttons: Array[Button] = []
var _upgrade_btns: Array[Button] = []          # 每槽右上角「升」金角标，仅就绪可升级时显示（C）


## 暗格底材质（cell_bg·与图鉴同 shader）：稀有度暗底 + 中心高亮 + 传说金底图。颜色/高亮每次 refresh 重设。
func _make_cell_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CELL_BG_SHADER
	m.set_shader_parameter("fill_opaque", 1.0)        # 实底（非叠加）
	m.set_shader_parameter("cloud_on", 0.0)
	m.set_shader_parameter("use_tex", 0.0)
	m.set_shader_parameter("corner_radius", CELL_CORNER)
	m.set_shader_parameter("pixel_grid", CELL_GRID)   # = 图鉴格数·边框/圆角与图鉴等比
	m.set_shader_parameter("center_glow", 0.55)
	m.set_shader_parameter("glow_radius", 0.62)
	return m


## 稀有度像素框材质（pixel_frame·与图鉴/英雄卡同 shader）。edge_mid/inner 每次 refresh 设状态/稀有度色。
func _make_frame_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", FRAME_EDGE_OUTER)
	m.set_shader_parameter("pixel_grid", CELL_GRID)   # = 图鉴格数·边框等比变薄（小框不再粗棕边）
	m.set_shader_parameter("border_px", 2.0)
	m.set_shader_parameter("noise_amt", 0.05)
	m.set_shader_parameter("light_amount", 0.18)     # 方向光浮雕（上/左提亮）
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("corner_radius", CELL_CORNER)
	return m


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_W * 3 + GAP * 2, SLOT_H)
	# 根容器不拦截点击：只让每个槽的按钮(STOP)接收（否则上层 HUD 容器会吞点击）。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var base := Vector2(i * (SLOT_W + GAP), 0.0)
		# 暗格底（cell_bg）：稀有度暗底 + 中心高亮 + 传说金底图；颜色由 refresh 设。
		var cell := ColorRect.new()
		cell.color = Color.WHITE   # shader 乘 COLOR，须白
		cell.position = base
		cell.size = Vector2(SLOT_W, SLOT_H)
		var cmat := _make_cell_material()
		cell.material = cmat
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		# 稀有度像素框（pixel_frame·中心透明只画边）：覆在格底上、图标之下。
		var frame := ColorRect.new()
		frame.color = Color.WHITE
		frame.position = base
		frame.size = Vector2(SLOT_W, SLOT_H)
		var fmat := _make_frame_material()
		frame.material = fmat
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
		# 道具图标层（铺在框之上、文字之下；缺图隐藏 → 回退文字）。
		var icon := TextureRect.new()
		icon.position = base + Vector2(ICON_INSET, ICON_INSET)
		icon.size = Vector2(SLOT_W - ICON_INSET * 2.0, SLOT_H - ICON_INSET * 2.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 小尺寸须 IGNORE_SIZE 否则被纹理顶大
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素清晰
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		add_child(icon)
		var lbl := Label.new()
		lbl.position = base
		lbl.size = Vector2(SLOT_W, SLOT_H)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_text = true   # 长道具名（占位文字）夹在芯片内·勿溢出（待换图标）
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", TXT_BRIGHT)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
		# 点击层（透明 flat 按钮，铺满整格）：仅 interactive 时吃点击。
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = base
		btn.size = Vector2(SLOT_W, SLOT_H)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		btn.pressed.connect(_on_slot_pressed.bind(i))
		add_child(btn)
		# 升级金角标（右上角·铺在点击层之上 → 角落点击=升级、槽身=使用）。默认隐藏，refresh 控显。
		var up := _make_upgrade_badge(base, i)
		add_child(up)
		_cells.append(cell)
		_cell_mats.append(cmat)
		_frames.append(frame)
		_frame_mats.append(fmat)
		_icons.append(icon)
		_labels.append(lbl)
		_buttons.append(btn)
		_upgrade_btns.append(up)


## 右上角「升」金色角标（jelly 金底 + 墨字·点角=升级·点槽身=使用）。
func _make_upgrade_badge(base: Vector2, i: int) -> Button:
	var up := Button.new()
	up.text = "升"
	up.flat = true
	up.focus_mode = Control.FOCUS_NONE
	up.position = base + Vector2(SLOT_W - 20.0, 1.0)
	up.size = Vector2(19.0, 17.0)
	up.add_theme_font_size_override("font_size", 10)
	up.add_theme_color_override("font_color", Color(0.25, 0.16, 0.04))   # 墨字压金
	up.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	up.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	up.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = Vector2(19.0, 17.0)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bm := ShaderMaterial.new()
	bm.shader = JELLY_SHADER
	bm.set_shader_parameter("fill_top", Color("ffd86a"))
	bm.set_shader_parameter("fill_bottom", Color("c89a30"))
	bm.set_shader_parameter("edge_inner", Color("fff0b0"))
	bm.set_shader_parameter("edge_outer", EDGE_OUTER)
	bm.set_shader_parameter("fill_alpha", 1.0)
	bm.set_shader_parameter("pixel_grid", 18.0)
	bm.set_shader_parameter("corner", 0.2)
	bm.set_shader_parameter("edge_px", 1.5)
	bm.set_shader_parameter("aspect", 19.0 / 17.0)
	bm.set_shader_parameter("noise_amt", 0.05)
	bm.set_shader_parameter("wear", 0.15)
	bg.material = bm
	up.add_child(bg)
	up.visible = false
	up.pressed.connect(_on_upgrade_pressed.bind(i))
	return up


func _on_slot_pressed(slot: int) -> void:
	if interactive:
		slot_clicked.emit(slot)


func _on_upgrade_pressed(slot: int) -> void:
	if interactive:
		slot_upgrade_clicked.emit(slot)


## 按经济状态刷新 3 个芯片（颜色 + 文字）。battle 未启用经济（槽空）时安全跳过。
## staged：本回合已点选「使用」的槽位（仅 P1 传入；用于亮金高亮）。
func refresh(battle: BattleCore, player: int, staged: Array = []) -> void:
	if battle == null or player < 0 or player >= battle.slots.size():
		return
	if battle.slots[player].size() < 3 or _cells.size() < 3:
		return
	for i in range(3):
		var st: int = battle.slot_state(player, i)
		var lbl: Label = _labels[i]
		var icon: TextureRect = _icons[i]
		icon.visible = false               # 默认隐藏 → 非 CHARGING / 缺图均回退文字（零回归）
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var ready := false                 # 本回合是否「有可操作动作」（决定金边）
		var cta := GOLD_OPEN               # 召唤操作用的金（经济操作=暗金；道具就绪=亮金）
		var ft := SEAL_FT
		var fb := SEAL_FB                   # = 暗格底色（fill_color）
		var ei := EMPTY_EDGE               # = 框 edge_mid；无道具=中性灰，有道具→下方设稀有度色
		var glow := 0.0                    # 内外渐变强度（有道具→1·中心亮四角深；传说=0 走金底图）
		var cell_inner := Color.WHITE      # 格底中心亮色（有道具时=稀有度亮调）
		var legend := false                # 传说→格底用 gold_bottom 美术图
		var has_item := false              # 该槽是否装着道具（有→框走稀有度色·不被经济金边覆盖）
		var tcol := TXT_BRIGHT             # 文字层级：静默态在下方 match 内改暗（优化点②）
		match st:
			BattleCore.SlotState.SEALED:
				# 未到解锁回合（格自动解锁·无开格操作）→ 显示解锁回合数电报（静默·文字退后）。
				lbl.text = "回合%d\n解锁" % (int(BattleCore.SLOT_UNLOCK_TURN[i]) + 1)
				tcol = TXT_DIM
			BattleCore.SlotState.OPENED:
				ft = NEU_FT; fb = NEU_FB; ei = EMPTY_EDGE
				if battle.can_draw_slot(player, i):
					lbl.text = "可抽"
					ready = true
				else:
					lbl.text = "待抽"
					tcol = TXT_DIM
			BattleCore.SlotState.CHARGING:
				var item: ItemData = battle.slot_item(player, i)
				has_item = item != null                     # 有道具 → 框走稀有度色（不被经济金边覆盖）
				legend = has_item and item.tier >= 3        # 传说 → 格底用 gold_bottom 金底图
				if has_item:
					glow = 0.0 if legend else 1.0           # 内外渐变（传说金底图自带亮心·不用）
				var nm: String = item.item_name if item != null else ""
				var dim: Color = _rarity_color(item)   # 框色按稀有度（变量名 dim 历史遗留）
				# 格底内外色（参传说 gold_bottom：中心亮/四角深·与图鉴同算法）。
				var c_out: Color = Color.from_hsv(dim.h, minf(dim.s * 1.05, 1.0), 0.76)   # 四角深·更饱和
				var c_in: Color = Color.from_hsv(dim.h, dim.s * 0.85, 0.89)               # 中心亮·略浅
				var tex: Texture2D = _icon_for(item.item_id) if item != null else null
				if tex != null:
					icon.texture = tex
					icon.visible = true
					lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # 状态标签落底·不挡图标
				if battle.slot_ready(player, i):
					ready = true
					# 就绪 = 稀有度内外渐变格底（中心亮四角深·与图鉴同）+ 稀有度框。
					fb = c_out                # 四角深
					cell_inner = c_in         # 中心亮
					ei = dim                  # 框 = 稀有度色（普通蓝/稀有紫/传说金）
					icon.modulate = Color.WHITE
					if tex != null:
						lbl.text = "✓用" if staged.has(i) else ""   # 有图 → 只留状态标签
					else:
						lbl.text = nm + "\n✓用" if staged.has(i) else nm   # 缺图回退名
				else:
					# 锁中 = 稀有度内外渐变压暗（仍认得出蓝/紫/金归属）+ 图标压暗。
					fb = c_out.darkened(0.32)
					cell_inner = c_in.darkened(0.32)
					ei = dim.darkened(0.35)
					icon.modulate = Color(0.62, 0.62, 0.66)   # 图标压暗 = 读作锁中
					lbl.text = "(锁)" if tex != null else nm + "\n(锁)"
					tcol = TXT_DIM
			BattleCore.SlotState.EMPTY:
				if battle.can_refill(player, i):
					lbl.text = "可补"
					ready = true
					ft = NEU_FT; fb = NEU_FB; ei = EMPTY_EDGE
				else:
					lbl.text = "空"
					ft = EMP_FT; fb = EMP_FB; ei = EMPTY_EDGE
					tcol = TXT_FAINT
		lbl.modulate = Color.WHITE
		lbl.add_theme_color_override("font_color", tcol)
		# 无道具格（锁/待抽/空/可抽）：连续内渐变代替死平底（craft 原则·§6「连续内阴影/渐变」·与图鉴格同手法）。
		# 中心以 ft（各态浅调常量）微亮、四角 fb——幅度克制，框仍安静。
		if not has_item:
			glow = 0.45
			cell_inner = ft
		# 金边只给「选中使用」和「经济可操作(可开/可抽/可补)」；有道具的框一律保持稀有度色（不被金边覆盖）。
		if staged.has(i):
			ei = GOLD_STAGED
		elif interactive and ready and not has_item:
			ei = cta
		# 应用到双层（图鉴形式）：暗格底 cell_bg（fill=fb 暗底 + center_glow 凸显图标 + 传说金底图）+ 稀有度像素框（edge=ei 状态色）。
		var cmat: ShaderMaterial = _cell_mats[i]
		cmat.set_shader_parameter("fill_color", fb)
		cmat.set_shader_parameter("inner_color", cell_inner)
		cmat.set_shader_parameter("center_glow", glow)
		cmat.set_shader_parameter("use_tex", 1.0 if legend else 0.0)
		if legend:
			cmat.set_shader_parameter("bg_tex", LEGENDARY_BG)
			cmat.set_shader_parameter("tex_tint", LEGENDARY_BG_TINT)
		var fmat: ShaderMaterial = _frame_mats[i]
		fmat.set_shader_parameter("edge_mid", ei)
		fmat.set_shader_parameter("edge_inner", ei.darkened(0.5))
		# 升级角标：仅本地玩家行 + 该槽可升级（就绪 + tier<3 + 能量够）时显示。
		_upgrade_btns[i].visible = interactive and battle.can_upgrade(player, i)


## 芯片底色（2026-06-26 Eddy：改按【稀有度】而非维度——普通灰/稀有蓝/传说金·与图鉴/抽卡同源）。
func _rarity_color(item: ItemData) -> Color:
	if item == null:
		return SEAL_FT
	return ItemCatalog.rarity_color(item.tier)


## 取道具图标（带缓存）；缺图 / 未导入返回 null → 回退占位文字。
func _icon_for(id: String) -> Texture2D:
	if not _icon_cache.has(id):
		_icon_cache[id] = ItemCatalog.load_icon(id)   # 可能为 null，缓存避免每帧 exists/load
	return _icon_cache[id]
