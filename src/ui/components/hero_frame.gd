class_name HeroFrame
extends Panel

## 回纹头像框(2026-07-13 换皮·同日二版：128px 精准资产+宝石退役+敌我=框色)：满幅头像 + 贴图边框 + 阵营暗底。
## 头像立绘(portrait_path·带背景方图) → 填满框内(stretch COVERED + clip)；底色层(BgFill)兜底头像没覆盖处(如底部)。
## 节点层级(自下而上)：BgFill → Portrait 头像(像素化+posterize·nearest) → InnerFX 内阴影+扫描线 → Bg 贴图边框 → NameLabel。
## 敌我=整框换色变体（我方暖骨 hero_avatar_frame.png / 敌方赤陶 _enemy.png·img_recolor 同源换色）——
## 四角阵营宝石(Corners)已退役(Eddy 2026-07-13)。按 player_color 红蓝倾向自动选贴图·调用方零改动。
## 状态走 Bg modulate：阵亡压灰·选中提亮。内部FX：PortraitMat 像素颗粒；InnerFXMat 暗角+扫描线。

## 选中补色（冷亮蓝白）：与战斗底部动作按钮 _set_btn_selected 的高亮一致。
const SELECTED_TINT := Color(1.28, 1.42, 1.6)

## 敌我框贴图（同源换色变体·tools/img_recolor.gd 产出）。
const FRAME_TEX := preload("res://assets/ui/hero_avatar_frame.png")             # 我方=暖骨
const FRAME_TEX_ENEMY := preload("res://assets/ui/hero_avatar_frame_enemy.png") # 敌方=亮赤 #C86A5E(B4544C 偏暗→提亮·2026-07-13)

@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		if is_node_ready():
			_refresh_portrait()

@export var hero_name: String = "":
	set(v):
		hero_name = v
		if is_node_ready() and _name_label:
			(_name_label as Label).text = v.substr(0, 2)

@export var is_active: bool = false:
	set(v):
		is_active = v
		if is_node_ready():
			_refresh_style()

## 选中态：替补被点选、准备换人时高亮（冷亮蓝白补色 + 弹跳放大）→ 选择动画，与底部动作按钮一致。
@export var is_selected: bool = false:
	set(v):
		is_selected = v
		if is_node_ready():
			_refresh_style()
			modulate = SELECTED_TINT if v else Color.WHITE   # 补色：与底部按钮选中同款冷亮蓝白
			_play_select_pop(v)

@export var player_color: Color = Color("#3f86c8"):
	set(v):
		player_color = v
		if is_node_ready():
			_refresh_style()

## ★ 圆角统一控制 ★ —— UV 比例半径(0=直角)，一处同步到全部 4 层(边框/头像/内阴影/底色)的像素圆角。
## 想整体调圆角就改这一个值（或在 HeroFrame 节点的 Inspector 改）。
@export_range(0.0, 0.4, 0.005) var corner_radius: float = 0.3:
	set(v):
		corner_radius = v
		if is_node_ready():
			_apply_corner_radius()

@export var is_dead: bool = false:
	set(v):
		is_dead = v
		if is_node_ready():
			_refresh_style()

@export var frame_size: Vector2 = Vector2(72, 72):
	set(v):
		frame_size = v
		if is_node_ready():
			size = v

## 头像水平翻转（P2 对手头像朝左用）。
@export var flip_h: bool = false:
	set(v):
		flip_h = v
		if is_node_ready() and _portrait:
			(_portrait as TextureRect).flip_h = v

var _portrait: TextureRect
var _name_label: Label
var _bg: TextureRect          # 贴图边框（2026-07-13 换皮·原 shader ColorRect）
var _bg_fill: ColorRect
var _inner_fx: ColorRect
var _switch_label: Label   # 主动换人：armed 时盖在立绘上显示「切换」二字（任务5）
var _sel_tween: Tween      # 选中弹跳动画（选择动作时的 pop）
static var _cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# 入树时套用 frame_size → size。frame_size 的 setter 仅在 is_node_ready() 才应用，
	# 若调用方在 add_child(节点未 ready·如游离 wrap) 之前设 frame_size，size 会停在默认值；
	# 这里在 _ready 兜底套用，保证任何用法下框尺寸都正确（修被动换人浮窗头像不对齐）。
	size = frame_size
	_setup_children()
	_apply_corner_radius()
	_refresh_portrait()
	_refresh_style()


func _setup_children() -> void:
	_portrait = _find_child_named("Portrait") as TextureRect
	_bg = _find_child_named("Bg") as TextureRect
	_bg_fill = _find_child_named("BgFill") as ColorRect
	_inner_fx = _find_child_named("InnerFX") as ColorRect
	_name_label = _find_child_named("NameLabel") as Label
	if _name_label:
		_name_label.visible = false   # 头像框不显示英雄名(节点保留备用)


func _find_child_named(cname: String) -> Node:
	for c in get_children():
		if c.name == cname:
			return c
	return null


## 把 corner_radius 一处同步到 4 层材质(边框/头像/内阴影/底色) → 统一控制圆角。
func _apply_corner_radius() -> void:
	for n in [_bg, _portrait, _inner_fx, _bg_fill]:
		if n != null and n.material is ShaderMaterial:
			(n.material as ShaderMaterial).set_shader_parameter("corner_radius", corner_radius)


func _refresh_portrait() -> void:
	if not _portrait:
		return
	if portrait_path == "" or not ResourceLoader.exists(portrait_path):
		_portrait.visible = false
		return
	# 头像立绘(带背景方图·无透明边)，整图填满即可，无需裁切。
	var tex: Texture2D
	if _cache.has(portrait_path):
		tex = _cache[portrait_path]
	else:
		tex = load(portrait_path)
		_cache[portrait_path] = tex
	(_portrait as TextureRect).texture = tex
	(_portrait as TextureRect).visible = true
	(_portrait as TextureRect).flip_h = flip_h


func _refresh_style() -> void:
	# 敌我=整框换色贴图（我方暖骨/敌方赤陶·按 player_color 红蓝倾向选）；状态走 Bg modulate。
	# 头像像素化/内阴影/扫描线由 PortraitMat + InnerFX 处理(常驻·与状态无关)。
	var fill: Color
	var frame_mod: Color
	if is_dead:
		fill = Color(0.1, 0.1, 0.11)
		frame_mod = Color(0.42, 0.43, 0.46)   # 贴图框压灰（≈旧灰边档位）
	else:
		fill = Color(0.17, 0.145, 0.115)      # 暖底·抬出近黑(原0.11像黑洞→暖深褐)
		frame_mod = Color.WHITE

	# 选中高亮（换人待确认）：提亮边框（≈旧 e_mid.lightened(0.4) 档位·偏暖）。
	if is_selected and not is_dead:
		frame_mod = Color(1.35, 1.32, 1.18)

	if _bg:
		_bg.texture = FRAME_TEX_ENEMY if player_color.r > player_color.b else FRAME_TEX
		_bg.modulate = frame_mod

	if _bg_fill:
		_bg_fill.color = fill

	if _portrait:
		if is_dead:
			(_portrait as TextureRect).modulate = Color(0.45, 0.45, 0.5)
		else:
			(_portrait as TextureRect).modulate = Color.WHITE

	if _name_label:
		(_name_label as Label).text = hero_name.substr(0, 2) if hero_name != "" else ""


func set_hp(_hp: int, _max_hp: int) -> void:
	pass


## 主动换人 armed 态（任务5）：on=立绘隐藏、框内居中显示「切换」二字 + 边框高亮放大；
## off=恢复立绘、去高亮。点替补框进入此态，再次点击=确认换人。
func set_switch_prompt(on: bool, label_text: String = "切换") -> void:
	if _switch_label == null:
		_switch_label = Label.new()
		_switch_label.name = "SwitchPrompt"
		_switch_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_switch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_switch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_switch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fm := get_node_or_null("/root/FontManager")
		if fm != null:
			fm.apply(_switch_label, 16)
		_switch_label.add_theme_color_override("font_color", Color.WHITE)
		_switch_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_switch_label.add_theme_constant_override("outline_size", 4)
		add_child(_switch_label)   # 加在最后 → 渲染在边框/立绘之上
	_switch_label.text = tr(label_text)   # 「切换」(己方换人) / 「揪」(h21 敌方揪目标) 复用同一 label
	_switch_label.visible = on
	if _portrait:
		if on:
			_portrait.visible = false
		else:
			_refresh_portrait()
	# armed ≠ selected（任务5修订）：仅显示「切换」二字 + 隐立绘，不自动高亮；
	# 选中高亮/选择动画由调用方再点一次时通过 is_selected 触发。


## 选择弹跳动画：选中=带 overshoot 放大(像底部按钮 ButtonJuice)；取消=回弹归位。
func _play_select_pop(on: bool) -> void:
	pivot_offset = size * 0.5
	if _sel_tween and _sel_tween.is_valid():
		_sel_tween.kill()
	_sel_tween = create_tween()
	if on:
		_sel_tween.tween_property(self, "scale", Vector2.ONE * 1.12, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_sel_tween.tween_property(self, "scale", Vector2.ONE, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
