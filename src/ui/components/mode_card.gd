@tool
class_name ModeCard
extends Button

## 命运牌模式入口（主菜单三牌阵·第七轮设计 2026-06-11）。
## 牌面=battle 框语言像素框 + 顶部小注 + 纹章（王冠纹理或单字大印）+ 底部名牌横带（牌名+副标）。
## 常态=银框；hover/手柄焦点=金框+放大（Eddy 决议：高亮+放大只属于悬停态，不属于某张固定的牌）。
## 牌体尺寸在 .tscn 里用 offsets 可视化调整；子节点全部运行时自绘（HeroFrame 同范式），
## 文案/纹章走 @export，未来换手绘牌面美术=替换纹章区贴图，结构不动。
##
## 用法：Button 节点挂本脚本，设置 card_title/card_subtitle/card_caption + emblem_char 或 use_crown。

const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")

# battle screen 框语言（hero_frame 同源）
const EDGE_OUTER := Color(0.05, 0.05, 0.06)
const SILVER_MID := Color(0.65, 0.67, 0.71)
const SILVER_INNER := Color(0.34, 0.36, 0.39)
const GOLD_MID := Color(0.79, 0.65, 0.29)
const GOLD_INNER := Color(0.45, 0.35, 0.15)
const GOLD_TEXT := Color("#f4c84b")

const FILL_COLD := Color(0.065, 0.075, 0.10, 0.97)   # 常态牌面（深板岩）
const FILL_WARM := Color(0.095, 0.085, 0.07, 0.97)   # 悬停牌面（微暖）
const TITLE_COLD := Color("#e4eaf2")
const SUB_COL := Color(0.667, 0.706, 0.769, 0.90)
const CAP_COL := Color(0.667, 0.706, 0.769, 0.55)
const EMBLEM_COL := Color(0.667, 0.706, 0.769, 0.85)

@export var card_title: String = "模式":
	set(v):
		card_title = v
		if _title:
			_title.text = v
@export var card_subtitle: String = "":
	set(v):
		card_subtitle = v
		if _sub:
			_sub.text = v
@export var card_caption: String = "":
	set(v):
		card_caption = v
		if _cap:
			_cap.text = "· %s ·" % v if v != "" else ""
@export var emblem_char: String = "":
	set(v):
		emblem_char = v
		if _emblem:
			_emblem.text = v
@export var use_crown: bool = false
@export var title_font_size: int = 32
## 悬停/焦点放大倍率（高亮+放大=悬停专属效果）。
@export_range(1.0, 1.2) var hover_grow: float = 1.05
## 名牌横带高度占牌高比例。
@export_range(0.1, 0.3) var band_ratio: float = 0.19

var _backing: ColorRect
var _fill: ColorRect
var _frame: ColorRect
var _frame_mat: ShaderMaterial
var _inner_lines: Array[ColorRect] = []
var _corner_bars: Array[ColorRect] = []      # 包角受光面（亮）
var _corner_shadows: Array[ColorRect] = []   # 包角厚度衬底（暗·偏移 2px 下右）
var _band: ColorRect
var _sep: ColorRect
var _title: Label
var _sub: Label
var _cap: Label
var _emblem: Label
var _crown: TextureRect

var _hot: bool = false
var _tw: Tween

# ---- 牌背模式（匹配中=盖牌等对手·主菜单匹配动画用）----
var _face_down: bool = false
var _gold_locked: bool = false       # 牌背期间金框常驻（不随鼠标进出变化）
var _crown_scale: float = 6.0        # 王冠纹章倍率：正面 ×6 / 牌背 ×4
var _flip_tw: Tween
var _breath_tw: Tween                # 牌背王冠呼吸
var _float_tw: Tween                 # 牌背轻浮动
var _float_home_y: float = 0.0


func _ready() -> void:
	# 清掉 Button 默认皮肤 → 牌面全自绘
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_build()
	_layout()
	_apply_palette()
	resized.connect(_layout)
	mouse_entered.connect(_set_hot.bind(true))
	mouse_exited.connect(_set_hot.bind(false))
	focus_entered.connect(_set_hot.bind(true))
	focus_exited.connect(_set_hot.bind(false))
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _build() -> void:
	_backing = _rect(EDGE_OUTER)
	_fill = _rect(FILL_COLD)
	_frame = _rect(Color.WHITE)
	_frame_mat = ShaderMaterial.new()
	_frame_mat.shader = FRAME_SHADER
	_frame_mat.set_shader_parameter("border_px", 1.5)
	_frame_mat.set_shader_parameter("noise_amt", 0.06)
	# 2026-06-11 2A 去科幻感：撤常态青镀线（冷色 emissive 细线=全息/科技 UI 公式）、撤竹节
	# （细框上等距分段读成铆钉/能量管节）。保留方向光（中性体积感）；金镀线改为 hover 专属
	# （_apply_palette 随 hot 开关）。质感重心移到四角双色金属包角。
	_frame_mat.set_shader_parameter("light_amount", 0.13)
	_frame.material = _frame_mat

	for i in 4:
		_inner_lines.append(_rect(Color.WHITE))
	# 四角金属包角 = 暗色厚度衬底（先建=画在下层）+ 亮色受光面（后建=画在上层）
	for i in 8:
		_corner_shadows.append(_rect(Color.WHITE))
	for i in 8:
		_corner_bars.append(_rect(Color.WHITE))

	_band = _rect(Color(0.0, 0.0, 0.0, 0.30))
	_sep = _rect(Color.WHITE)

	_cap = _label(CAP_COL)
	_cap.text = "· %s ·" % card_caption if card_caption != "" else ""
	_title = _label(TITLE_COLD)
	_title.text = card_title
	_sub = _label(SUB_COL)
	_sub.text = card_subtitle
	_emblem = _label(EMBLEM_COL)
	_emblem.text = emblem_char

	if use_crown and not Engine.is_editor_hint():
		_crown = TextureRect.new()
		_crown.texture = PixelGlyphs.crown_texture()
		_crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_crown.stretch_mode = TextureRect.STRETCH_SCALE
		_crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_crown)

	if not Engine.is_editor_hint():
		FontManager.apply(_cap, 14)
		FontManager.apply(_title, title_font_size)
		FontManager.apply(_sub, 16)
		FontManager.apply(_emblem, 96)


## 牌面布局：全部按当前 size 计算（.tscn 改 offsets 即所见即所得）。
func _layout() -> void:
	pivot_offset = size * 0.5
	var band_h := size.y * band_ratio

	_backing.position = Vector2.ZERO
	_backing.size = size
	_fill.position = Vector2(4, 4)
	_fill.size = size - Vector2(8, 8)
	_frame.position = Vector2.ZERO
	_frame.size = size
	_frame_mat.set_shader_parameter("pixel_grid", size.x / 5.0)

	# 内细线框
	var inset := 18.0
	var lines: Array[Rect2] = [
		Rect2(inset, inset, size.x - inset * 2.0, 1),
		Rect2(inset, size.y - inset, size.x - inset * 2.0, 1),
		Rect2(inset, inset, 1, size.y - inset * 2.0),
		Rect2(size.x - inset, inset, 1, size.y - inset * 2.0),
	]
	for i in 4:
		_inner_lines[i].position = lines[i].position
		_inner_lines[i].size = lines[i].size

	# 四角金属包角（2A：L 形角花升级双色——亮受光面 + 暗厚度衬底偏移 2px 下右，
	# 顶光方向与边框方向光/标题投影一致；角落承重=手工感，替代被撤的边中段细节）
	var arm := 20.0
	var th := 4.0
	var pad := inset + 6.0
	var origins: Array = [
		[Vector2(pad, pad), Vector2(1, 1)],
		[Vector2(size.x - pad, pad), Vector2(-1, 1)],
		[Vector2(pad, size.y - pad), Vector2(1, -1)],
		[Vector2(size.x - pad, size.y - pad), Vector2(-1, -1)],
	]
	var shadow_off := Vector2(2, 2)
	for i in 4:
		var origin: Vector2 = origins[i][0]
		var dir: Vector2 = origins[i][1]
		var hbar := _corner_bars[i * 2]
		hbar.position = Vector2(origin.x if dir.x > 0 else origin.x - arm,
			origin.y if dir.y > 0 else origin.y - th)
		hbar.size = Vector2(arm, th)
		var vbar := _corner_bars[i * 2 + 1]
		vbar.position = Vector2(origin.x if dir.x > 0 else origin.x - th,
			origin.y if dir.y > 0 else origin.y - arm)
		vbar.size = Vector2(th, arm)
		for k in 2:
			var bright := _corner_bars[i * 2 + k]
			var shadow := _corner_shadows[i * 2 + k]
			shadow.position = bright.position + shadow_off
			shadow.size = bright.size

	# 名牌横带
	var band_y := size.y - band_h
	_band.position = Vector2(8, band_y)
	_band.size = Vector2(size.x - 16, band_h - 10)
	_sep.position = Vector2(24, band_y)
	_sep.size = Vector2(size.x - 48, 2)

	_cap.position = Vector2(0, 20)
	_cap.size = Vector2(size.x, 22)
	_title.position = Vector2(0, band_y + 16)
	_title.size = Vector2(size.x, title_font_size * 1.4)
	_sub.position = Vector2(0, band_y + 16 + title_font_size + 12)
	_sub.size = Vector2(size.x, 26)

	# 纹章居中于美术区（名牌带以上）
	var art_h := size.y - band_h
	_emblem.position = Vector2(0, art_h * 0.5 - 70)
	_emblem.size = Vector2(size.x, 140)
	if _crown:
		_crown.size = Vector2(_crown.texture.get_size()) * _crown_scale
		_crown.position = Vector2((size.x - _crown.size.x) * 0.5, (art_h - _crown.size.y) * 0.5)


## 银/金两套牌面（金=悬停/焦点专属；牌背模式金框常驻）。
func _apply_palette() -> void:
	var hot := _hot or _gold_locked
	var mid := GOLD_MID if hot else SILVER_MID
	var inner := GOLD_INNER if hot else SILVER_INNER
	_frame_mat.set_shader_parameter("edge_outer", EDGE_OUTER)
	_frame_mat.set_shader_parameter("edge_mid", mid)
	_frame_mat.set_shader_parameter("edge_inner", inner)
	# 内缘镀线 = hover/焦点专属亮金（加冕语义）；常态无镀线——状态编码靠"平时没有金"
	# （2A：常态月光青已撤，冷色 emissive 线=科幻 UI 公式，与本作题材不符）
	_frame_mat.set_shader_parameter("accent_strength", 0.6 if hot else 0.0)
	_frame_mat.set_shader_parameter("accent_color", Color(1.0, 0.878, 0.541))
	_fill.color = FILL_WARM if hot else FILL_COLD
	_sep.color = Color(mid, 0.5)
	_title.add_theme_color_override("font_color", GOLD_TEXT if hot else TITLE_COLD)
	for ln in _inner_lines:
		ln.color = Color(mid, 0.30)
	# 金属包角：受光面实色 + 厚度衬底用边框内层深色（银/金随态）
	for cb in _corner_bars:
		cb.color = Color(mid, 0.95)
	for cs in _corner_shadows:
		cs.color = Color(inner, 0.90)


func _set_hot(hot: bool) -> void:
	if disabled or _face_down:
		return
	if _hot == hot:
		return
	_hot = hot
	_apply_palette()
	z_index = 1 if hot else 0
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * (hover_grow if hot else 1.0), 0.18)\
		.set_trans(Tween.TRANS_BACK if hot else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_down() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * (hover_grow * 0.96 if _hot else 0.97), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_up() -> void:
	_set_pressed_rebound()


func _set_pressed_rebound() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * (hover_grow if _hot else 1.0), 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ── 牌背模式（匹配中=盖牌等对手）──

## 翻面（横向压缩→中点换面→回弹展开·BP REVEAL 同语言）。await 可等动画完成。
## down=true 进牌背：隐藏正面信息（小注/字印），王冠缩小+呼吸+牌体轻浮动，金框常驻；
## down=false 翻回正面恢复一切。牌名/副标文字由调用方（main_menu）通过 card_title/card_subtitle 改。
func flip_face(down: bool) -> void:
	if _face_down == down:
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	if _flip_tw and _flip_tw.is_valid():
		_flip_tw.kill()
	if not down:
		_stop_back_anims()
	# 压缩（顺带把 hover 缩放归一，防止翻完后 x/y 不一致）
	_flip_tw = create_tween().set_parallel(true)
	_flip_tw.tween_property(self, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tw.tween_property(self, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _flip_tw.finished
	_face_down = down
	_gold_locked = down
	_apply_face()
	_apply_palette()
	_flip_tw = create_tween()
	_flip_tw.tween_property(self, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _flip_tw.finished
	if down:
		_start_back_anims()


## 匹配成功一拍：王冠闪金 + 牌体弹震（屏幕轻震由 main_menu 负责）。
func found_flash() -> void:
	_stop_back_anims()
	if _crown:
		_crown.modulate = Color(2.2, 2.2, 1.5)
		var tc := create_tween()
		tc.tween_property(_crown, "modulate", Color.WHITE, 0.35)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 牌背内容切换：正面信息收起 / 王冠倍率切换（_layout 复用 _crown_scale）。
func _apply_face() -> void:
	_cap.visible = not _face_down and card_caption != ""
	_emblem.visible = not _face_down and emblem_char != ""
	_crown_scale = 4.0 if _face_down else 6.0
	_layout()


## 牌背待机：王冠呼吸（明暗 1.5s 周期）+ 牌体轻浮动（±3px 正弦）——"盖着的牌在等待中活着"。
func _start_back_anims() -> void:
	if _crown:
		_breath_tw = create_tween().set_loops()
		_breath_tw.tween_property(_crown, "modulate:a", 0.55, 0.75)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breath_tw.tween_property(_crown, "modulate:a", 1.0, 0.75)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_home_y = position.y
	_float_tw = create_tween().set_loops()
	_float_tw.tween_property(self, "position:y", _float_home_y - 3.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tw.tween_property(self, "position:y", _float_home_y + 3.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_back_anims() -> void:
	if _breath_tw and _breath_tw.is_valid():
		_breath_tw.kill()
	if _float_tw and _float_tw.is_valid():
		_float_tw.kill()
		position.y = _float_home_y
	if _crown:
		_crown.modulate.a = 1.0


# ── 节点工厂 ──

func _rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _label(col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
