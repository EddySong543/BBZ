class_name HeroCard
extends Button

## Ban/Pick 英雄卡 —— 像素框风格（复用战斗/图鉴的边框 shader + 四角阵营宝石 corner_overlay）。
## 结构（hero_card.tscn）：PortraitCell( BgFill 暗底 + Portrait 头像 posterize + InnerFX 内阴影
##   + Frame 像素边框 + Corners 四角宝石 + HPBadge ) + NameLabel。
## 5 态视觉由代码设 Frame 的 edge_* uniform + Corners.corner_color 实现：
##   NORMAL 锡灰 / SELECTED 描金+宝石 / PICKED_P1 蓝 / PICKED_P2 红 /
##   BANNED 灰框+头像暗幕+**大号像素红✕**（2026-06-12 Eddy：旧"灰+细角线X"一眼认不出已废）。
## 选中态额外走 ButtonJuice 放大；禁用红✕=懒建 BanVeil/BanMark 盖在 PortraitCell 最上层。
## 组队三分类框模式（2026-07-18 Eddy·opt-in=设 team_role 即启用·BP 用）：shader 框+四角宝石
## 退场，换 hero_avatar_frame 美术素材换色变体，框色=英雄类型恒色（进攻红/防守蓝/经济金）
## 不再随状态变色；状态语义转移：已入手=头像压灰（dim_when_picked）·归属=名字色·禁用=暗幕+红✕照旧。
## 不设 team_role 的调用方走原五态路径零影响。

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

## 墨字名模式（opt-in·默认关=战斗路径零影响）：卡摆在亮纸面上时（BP 牌池桌面·2026-07-16）
## 状态色白/蓝名会洗白——开启后名字恒墨字+去描边，阵营/禁用语义交给框色与暗幕承担。
@export var ink_name: bool = false:
	set(v):
		ink_name = v
		if is_node_ready():
			_refresh_style()

const INK_NAME := Color(0.24, 0.19, 0.12)   # 墨字（图鉴家族同值）

## 玩家面三分类（经济/进攻/防守·占位命名待 Eddy 定稿）→ 恒色美术框。值来自 HeroData.team_role。
@export var team_role: String = "":
	set(v):
		team_role = v
		if is_node_ready():
			_refresh_style()
@export var dim_when_picked: bool = false   # 池卡「已入手留印」：PICKED 态头像压灰（手牌/仪式卡勿开）

# 类型→框素材（hero_avatar_frame 换色变体·战斗四色版同源：攻红 c4523e/防蓝 4a7db8/攒金 d9ae4b）
const TYPE_FRAME_PATH := {
	"进攻": "res://assets/ui/hero_avatar_frame_atk.png",
	"防守": "res://assets/ui/hero_avatar_frame_def.png",
	"经济": "res://assets/ui/hero_avatar_frame_econ.png",
}
# 已入手留印=轻暗幕（BanVeil 同族更淡·无✕）。⚠不能走 Portrait.modulate——
# portrait_pixelate shader 片元只用纯纹理 rgb（防纹理²压黑），rgb modulate 是死通道。
const PICK_VEIL_COLOR := Color(0.02, 0.03, 0.05, 0.32)

var _portrait: TextureRect
var _frame: ColorRect
var _corners: Control
var _role_frame: TextureRect      # 类型恒色美术框（懒建·仅 team_role 模式可见）
var _name_label: Label
var _hp_badge: IconBadge          # 爱心内嵌血量数字（骑在框外左上角·任务1）
var _juice: ButtonJuice
var _ban_veil: ColorRect          # 禁用暗幕（懒建·仅 BANNED 可见）
var _ban_mark: BanMark            # 禁用大红✕（懒建·盖在暗幕上）
var _pick_veil: ColorRect         # 已入手留印轻幕（懒建·仅类型框模式池卡 PICKED 可见）
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
		_name_label.text = tr(hero_name)
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

	var role_tex := _role_frame_texture()
	if role_tex:
		# 类型框模式：美术框恒色=英雄身份，状态不碰框色（框色语义已让给类型）。
		_ensure_role_frame()
		_role_frame.texture = role_tex
		_role_frame.visible = true
		_frame.visible = false
		if _corners:
			_corners.visible = false
		var picked := card_state == CardState.PICKED_P1 or card_state == CardState.PICKED_P2
		_set_pick_veil(picked and dim_when_picked)
	else:
		_set_pick_veil(false)
		if _role_frame:
			_role_frame.visible = false
		_frame.visible = true
		if _corners:
			_corners.visible = true
		if _frame and _frame.material is ShaderMaterial:
			var m := _frame.material as ShaderMaterial
			m.set_shader_parameter("edge_outer", e_outer)
			m.set_shader_parameter("edge_mid", e_mid)
			m.set_shader_parameter("edge_inner", e_inner)
		if _corners:
			_corners.set("corner_color", gem)

	if _portrait:
		_portrait.modulate = port_mod

	var is_banned := card_state == CardState.BANNED
	if _name_label:
		if ink_name:   # 亮纸面模式：恒墨字（禁用=淡墨）+去描边·语义走框色
			_name_label.add_theme_color_override("font_color",
				Color(INK_NAME, 0.45) if is_banned else INK_NAME)
			_name_label.add_theme_constant_override("outline_size", 0)
		else:
			_name_label.add_theme_color_override("font_color", name_col)
	if _hp_badge:
		_hp_badge.modulate = Color(0.5, 0.5, 0.56) if is_banned else Color.WHITE

	if is_banned:
		_ensure_ban_overlay()
	if _ban_mark:
		_ban_veil.visible = is_banned
		_ban_mark.visible = is_banned

	if _juice:
		_juice.set_selected(card_state == CardState.SELECTED)


static var _type_frame_cache: Dictionary = {}   # path → Texture2D（24 卡共享·避免逐卡重载）

func _role_frame_texture() -> Texture2D:
	if not TYPE_FRAME_PATH.has(team_role):
		return null
	var p: String = TYPE_FRAME_PATH[team_role]
	if not _type_frame_cache.has(p):
		_type_frame_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _type_frame_cache[p]


## 类型美术框（懒建）：盖在 shader Frame 之上、Corners/禁用层之下，满铺头像格。
func _ensure_role_frame() -> void:
	if _role_frame:
		return
	_role_frame = TextureRect.new()
	_role_frame.name = "RoleFrame"
	_role_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_role_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_role_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$PortraitCell.add_child(_role_frame)
	$PortraitCell.move_child(_role_frame, _frame.get_index() + 1)


## 已入手留印轻幕（懒建）：盖住整个头像格含框（框色随之变哑=「拿走了」），
## 比禁用幕淡、无✕；与 BANNED 互斥（被禁的卡不可能被选走）。
func _set_pick_veil(on: bool) -> void:
	if not on and _pick_veil == null:
		return
	if _pick_veil == null:
		_pick_veil = ColorRect.new()
		_pick_veil.name = "PickVeil"
		_pick_veil.color = PICK_VEIL_COLOR
		_pick_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pick_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$PortraitCell.add_child(_pick_veil)
		if _ban_veil:   # 万一禁用层已建，留印幕排它下面（红✕永远最上）
			$PortraitCell.move_child(_pick_veil, _ban_veil.get_index())
	_pick_veil.visible = on


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
