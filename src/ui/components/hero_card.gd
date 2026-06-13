class_name HeroCard
extends Button

## Ban/Pick 英雄卡 —— 像素框风格（复用战斗/图鉴的边框 shader + 四角阵营宝石 corner_overlay）。
## 结构（hero_card.tscn）：PortraitCell( BgFill 暗底 + Portrait 头像 posterize + InnerFX 内阴影
##   + Frame 像素边框 + Corners 四角宝石 + HPBadge ) + NameLabel。
## 5 态视觉由代码设 Frame 的 edge_* uniform + Corners.corner_color 实现：
##   NORMAL 锡灰 / SELECTED 描金+宝石 / PICKED_P1 蓝 / PICKED_P2 红 /
##   BANNED 灰框+头像暗幕+**大号像素红✕**（2026-06-12 Eddy：旧"灰+细角线X"一眼认不出已废）。
## 选中态额外走 ButtonJuice 放大；禁用红✕=懒建 BanVeil/BanMark 盖在 PortraitCell 最上层。

enum CardState { NORMAL, SELECTED, PICKED_P1, PICKED_P2, BANNED }

@export var hero_id: String = ""
@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready():
			_refresh_text()
@export var max_hp: int = 10:
	set(v):
		max_hp = v
		if is_node_ready():
			_refresh_text()
@export var role_text: String = ""        # 保留字段（调用方设置）；当前卡面暂不展示职业
@export var position_text: String = ""     # 同上
@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_load_portrait()
@export var card_state: int = 0:
	set(v):
		card_state = v
		if is_node_ready():
			_refresh_style()

var _portrait: TextureRect
var _frame: ColorRect
var _corners: Control
var _name_label: Label
var _hp_badge: IconBadge          # 爱心内嵌血量数字（骑在框外左上角·任务1）
var _juice: ButtonJuice
var _ban_veil: ColorRect          # 禁用暗幕（懒建·仅 BANNED 可见）
var _ban_mark: BanMark            # 禁用大红✕（懒建·盖在暗幕上）
static var _portrait_cache: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(130, 158)
	# 去掉默认按钮外观（像素框 shader 当外观），各态统一空 stylebox。
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())

	_portrait = $PortraitCell/Portrait
	_frame = $PortraitCell/Frame
	_corners = $PortraitCell/Corners
	_name_label = $NameLabel
	_hp_badge = $HPBadge

	FontManager.apply(_name_label, 16)
	_style_text(_name_label, Color.WHITE)

	_juice = ButtonJuice.new()
	_juice.name = "ButtonJuice"
	add_child(_juice)

	_load_portrait()
	_refresh_text()
	_refresh_style()


## 文字描黑边 → 在头像/夜空上清晰可读。
## ⚠ 描边只能 2px（2026-06-12 Eddy）：16px 像素字笔画宽仅 1px，描 4px 会灌满汉字内空，
## 池卡再缩 0.846 直接糊成团；投影同理删除（分数缩放下投影变虚边）。
func _style_text(lbl: Label, col: Color) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))


func _refresh_text() -> void:
	if _name_label:
		_name_label.text = hero_name
	if _hp_badge:
		_hp_badge.set_number(max_hp)


## 名字反缩放补偿（2026-06-12 Eddy："名字糊在一起"根修）：卡片整体被 parent_scale
## 缩放时（bp 池/图鉴网格 0.846），字会落在非整数采样上发糊。
## 调用本方法 → 标签按 1/parent_scale 反向放大 → 合成变换 = 1.0，字以整数像素渲染。
## 2026-06-13 Eddy："图鉴/BP 名字太细太小" → 字号 12→16（f16 原生·反缩放后仍整数渲染、
## 既清晰又更大；标签宽 130 容 4 字 16px 绰绰有余）。须在 add_child 之后调用（节点要 ready）。
func compensate_name_scale(parent_scale: float) -> void:
	if _name_label == null or parent_scale <= 0.0:
		return
	FontManager.apply(_name_label, 16)
	_name_label.pivot_offset = _name_label.size * 0.5
	_name_label.scale = Vector2.ONE / parent_scale


func _load_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	var tex: Texture2D
	if _portrait_cache.has(portrait_path):
		tex = _portrait_cache[portrait_path]
	else:
		tex = load(portrait_path)
		_portrait_cache[portrait_path] = tex
	_portrait.texture = tex
	_portrait.visible = true


func _refresh_style() -> void:
	# 边框三层色 + 四角宝石色 + 头像变灰 + 选中放大，按 card_state 切换。
	# B 典籍朱印（2026-06-13）：常态边转暖骨色（清而不脏），选中=金、P1/P2=阵营蓝/红 不变。
	var e_outer := Color(0.05, 0.045, 0.04)
	var e_mid := Color(0.70, 0.64, 0.52)   # 暖骨色（中性·清）
	var e_inner := Color(0.42, 0.36, 0.26)
	var gem := Color(0.62, 0.56, 0.46)     # 暖中性淡宝石
	var port_mod := Color.WHITE
	var name_col := Color.WHITE

	match card_state:
		CardState.SELECTED:
			e_mid = Color(0.99, 0.85, 0.5)     # 描金
			e_inner = Color(0.6, 0.46, 0.16)
			gem = Color(0.99, 0.85, 0.5)
			name_col = Color(1.0, 0.92, 0.66)
		CardState.PICKED_P1:
			e_mid = Color(0.36, 0.6, 0.9)      # 我方蓝
			e_inner = Color(0.16, 0.28, 0.48)
			gem = Color(0.4, 0.66, 1.0)
			name_col = Color(0.74, 0.86, 1.0)
		CardState.PICKED_P2:
			e_mid = Color(0.85, 0.36, 0.32)    # 敌方红
			e_inner = Color(0.46, 0.16, 0.15)
			gem = Color(0.95, 0.42, 0.38)
			name_col = Color(1.0, 0.78, 0.74)
		CardState.BANNED:
			e_outer = Color(0.03, 0.03, 0.04)
			e_mid = Color(0.3, 0.3, 0.33)
			e_inner = Color(0.15, 0.15, 0.17)
			gem = Color(0.62, 0.63, 0.7)       # 禁用灰
			port_mod = Color(0.5, 0.5, 0.55)   # 转灰交给暗幕叠加（mod 太黑会认不出是谁）
			name_col = Color(0.5, 0.5, 0.56)

	if _frame and _frame.material is ShaderMaterial:
		var m := _frame.material as ShaderMaterial
		m.set_shader_parameter("edge_outer", e_outer)
		m.set_shader_parameter("edge_mid", e_mid)
		m.set_shader_parameter("edge_inner", e_inner)

	if _corners:
		_corners.set("corner_color", gem)

	if _portrait:
		_portrait.modulate = port_mod

	if _name_label:
		_name_label.add_theme_color_override("font_color", name_col)
	var is_banned := card_state == CardState.BANNED
	if _hp_badge:
		_hp_badge.modulate = Color(0.5, 0.5, 0.56) if is_banned else Color.WHITE

	if is_banned:
		_ensure_ban_overlay()
	if _ban_mark:
		_ban_veil.visible = is_banned
		_ban_mark.visible = is_banned

	if _juice:
		_juice.set_selected(card_state == CardState.SELECTED)


## 禁用覆盖层（懒建·首次进 BANNED 才创建）：暗幕压住整个头像格（含边框），
## 大号像素红✕盖最上 → 隔三米一眼认出"这张被禁了"。
func _ensure_ban_overlay() -> void:
	if _ban_mark:
		return
	_ban_veil = ColorRect.new()
	_ban_veil.name = "BanVeil"
	_ban_veil.color = Color(0.02, 0.03, 0.05, 0.45)
	_ban_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ban_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PortraitCell.add_child(_ban_veil)
	_ban_mark = BanMark.new()
	_ban_mark.name = "BanMark"
	_ban_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$PortraitCell.add_child(_ban_mark)


## 大号禁用红✕：两道像素台阶粗斜杠（暗衬底描边 + BP 主题红主体），
## 与像素边框同格（block≈格宽/24），corner_overlay._pixel_line 同源画法加粗为 2×2 块簇。
class BanMark extends Control:
	const X_RED := Color("#d8453e")
	const X_DARK := Color(0.04, 0.02, 0.02, 0.9)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var block := maxf(roundf(size.x / 24.0), 3.0)
		var ins := block * 4.0
		var cells: Array[Vector2] = []
		_collect(Vector2(ins, ins), Vector2(size.x - ins, size.y - ins), block, cells)
		_collect(Vector2(size.x - ins, ins), Vector2(ins, size.y - ins), block, cells)
		# 两道斜杠先齐画衬底、再齐画红体 → 交叉处不露暗缝
		for c in cells:
			draw_rect(Rect2(c.x - 2.0, c.y - 2.0, block * 2.0 + 4.0, block * 2.0 + 4.0), X_DARK)
		for c in cells:
			draw_rect(Rect2(c.x, c.y, block * 2.0, block * 2.0), X_RED)

	## 量化到格坐标逐格行走（corner_overlay 同法），收集每格 2×2 块簇的左上角。
	func _collect(a: Vector2, b: Vector2, block: float, out: Array[Vector2]) -> void:
		var ca := Vector2(roundf(a.x / block), roundf(a.y / block))
		var cb := Vector2(roundf(b.x / block), roundf(b.y / block))
		var steps := int(maxf(absf(cb.x - ca.x), absf(cb.y - ca.y)))
		for i in steps + 1:
			var t := float(i) / maxf(float(steps), 1.0)
			out.append(Vector2(
				roundf(lerpf(ca.x, cb.x, t)) * block - block * 0.5,
				roundf(lerpf(ca.y, cb.y, t)) * block - block * 0.5))
