class_name DeathSwitchOverlay
extends Control

## 阵亡替补选择浮窗 —— 全屏暗化背景 + 居中提示 + 倒计时 + 横排「头像框」(HeroFrame 同款，与战斗内一致)。
## 通过 show_selection(player, reserves) 弹出；用户点击某个头像框后发出 selection_made(slot)。
##
## 倒计时(PICK_SECONDS=10 秒)：到点未选则自动选最左侧(reserves[0]，即首个存活替补)并发出 selection_made。
## 血量显示 = ❤X：心形美术图标(heart_idle.png 单颗) + 数字（与战斗内备选英雄一致）。
## 每个替补 = 居中竖排：头像框 + 名字 + ❤血量（固定 FRAME_SIZE 宽对齐，杜绝歪斜）。

const HeroFrameScene := preload("res://src/ui/components/hero_frame.tscn")
const HEART_SHEET := preload("res://assets/ui/icons/heart_idle.png")   # ❤ 美术资产(4 帧 idle 精灵图)
const FRAME_SIZE := 120.0
const PICK_SECONDS := 10

signal selection_made(slot: int)

@onready var _prompt: Label = $PromptLabel
@onready var _countdown: Label = $CountdownLabel
@onready var _card_container: HBoxContainer = $CardContainer

var _time_left: float = 0.0
var _counting: bool = false
var _default_slot: int = -1   # 倒计时归零时自动选的槽位（= 最左侧 / 首个存活替补）


func _ready() -> void:
	FontManager.apply(_prompt, 32)   # 32=16×2 整数倍·清晰
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(_countdown, 48)   # 倒计时大数字（48=16×3 整数倍·清晰）
	_countdown.add_theme_color_override("font_color", Color.WHITE)
	visible = false
	set_process(false)


## 弹出浮窗。reserves 数组每项为 [slot_idx:int, hero:HeroData, hp:float]（多余元素忽略）。
## title 可覆盖提示文案（加时赛选人复用本浮窗·2026-07-03）。
func show_selection(player: int, reserves: Array, title: String = "选择出战英雄") -> void:
	_prompt.text = title

	for child in _card_container.get_children():
		child.queue_free()

	_default_slot = int(reserves[0][0]) if reserves.size() > 0 else -1

	var pcolor := Color("#3f86c8") if player == 0 else Color("#d24a44")  # 阵营宝石色(与战斗内一致)
	for entry in reserves:
		var slot_idx: int = int(entry[0])
		var h: HeroData = entry[1]
		var hp: float = float(entry[2])
		_card_container.add_child(_create_frame_entry(h, hp, slot_idx, pcolor))

	visible = true
	_time_left = float(PICK_SECONDS)
	_counting = true
	_update_countdown_label()
	set_process(true)


## 倒计时：每帧递减，归零自动选最左侧替补。
func _process(delta: float) -> void:
	if not _counting:
		return
	_time_left -= delta
	_update_countdown_label()
	if _time_left <= 0.0:
		_counting = false
		set_process(false)
		_on_selected(_default_slot)


func _update_countdown_label() -> void:
	var secs := maxi(int(ceil(_time_left)), 0)
	_countdown.text = "%d" % secs
	# 最后 3 秒转红催促。
	_countdown.add_theme_color_override("font_color", Color("#ff6666") if secs <= 3 else Color.WHITE)


## 单个替补 = 居中竖排(固定 FRAME_SIZE 宽对齐)：头像框(HeroFrame 同款) + 名字 + ❤X 血量。
func _create_frame_entry(h: HeroData, hp: float, slot: int, pcolor: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE + 72.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := HeroFrameScene.instantiate() as HeroFrame
	wrap.add_child(frame)
	# frame_size 等属性在 add_child 后设置；HeroFrame._ready 已兜底 size=frame_size，
	# 即便此时节点尚未真正入树(wrap 还游离)，入树时也会套用正确尺寸 → 对齐稳定。
	frame.position = Vector2.ZERO
	frame.frame_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	frame.portrait_path = h.portrait_path
	frame.hero_name = h.hero_name
	frame.player_color = pcolor
	frame.is_active = false
	frame.is_dead = false
	frame.gui_input.connect(_on_frame_input.bind(slot))

	var name_lbl := Label.new()
	name_lbl.text = h.hero_name
	name_lbl.position = Vector2(0, FRAME_SIZE + 6.0)
	name_lbl.size = Vector2(FRAME_SIZE, 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontManager.apply(name_lbl, 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(name_lbl)

	# 血量 = ❤X：心形美术图标(单颗 heart_idle.png) + 数字，水平居中成一组（❤ 用美术资产，非文本字符）。
	var hp_box := HBoxContainer.new()
	# x=-5 补偿心形美术左侧透明留白(约11px)——否则 HBox 几何居中会让可见内容整体右移 ~5px，
	# 与上方头像框/角色名(均居中于 0..FRAME_SIZE)不齐。偏移量与数字位数无关(已推导抵消)。
	hp_box.position = Vector2(-5.0, FRAME_SIZE + 28.0)
	hp_box.size = Vector2(FRAME_SIZE, 40.0)
	hp_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_box.add_theme_constant_override("separation", -8)   # 负间距补偿心形美术四周透明留白(61%)，让数字贴近心形
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var heart := IconPipRow.new()
	heart.sheet = HEART_SHEET
	heart.hframes = 4
	heart.spacing = 0.0
	heart.pip_size = 36.0
	heart.show_empty = false
	heart.allow_half = false
	heart.custom_minimum_size = Vector2(36.0, 36.0)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.set_value(1.0, 1.0)               # 固定画 1 颗心形图标(❤)
	hp_box.add_child(heart)

	var hp_lbl := Label.new()
	hp_lbl.text = _fmt_hp(hp)
	var hp_bold := FontVariation.new()
	hp_bold.base_font = FontManager.f16
	hp_bold.variation_embolden = 0.7
	hp_lbl.add_theme_font_override("font", hp_bold)
	hp_lbl.add_theme_font_size_override("font_size", 16)
	hp_lbl.add_theme_color_override("font_color", Color("#d7342e"))   # = 爱心红(与战斗内备选一致)
	hp_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_box.add_child(hp_lbl)

	wrap.add_child(hp_box)

	return wrap


## 血量数字：整数显示整数，半点显示一位小数。
func _fmt_hp(v: float) -> String:
	v = maxf(v, 0.0)
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v


func _on_frame_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_selected(slot)


func _on_selected(slot: int) -> void:
	_counting = false
	set_process(false)
	visible = false
	selection_made.emit(slot)
