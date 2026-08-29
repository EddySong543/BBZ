class_name DeathSwitchOverlay
extends Control

## 阵亡替补选择浮窗：轻压暗战场，只保留标题与横排替补头像。
## 候选头像直接复用战斗 HUD 的 HeroFrame 菱形模式；倒计时只由 BattleScreen 顶部统一管理。

const HeroFrameScene := preload("res://src/ui/components/hero_frame.tscn")
const ReserveHpRowScript := preload("res://src/ui/components/reserve_hp_row.gd")
const RoundLabelOrnamentsComponent := preload("res://src/ui/components/round_label_ornaments.gd")
const FRAME_SIZE := 112.0
## 顶部出战框的 80px / 6px / 2px / 1.5px 是当前视觉基线；死亡换人只做 1.4 倍等比放大。
const TOP_FRAME_SIZE := 80.0
const TOP_FRAME_STROKE := 6.0
const TOP_FRAME_RIM := 2.0
const TOP_FRAME_INNER_RIM := 1.5
const FRAME_SCALE := FRAME_SIZE / TOP_FRAME_SIZE
const FRAME_STROKE := TOP_FRAME_STROKE * FRAME_SCALE
const FRAME_RIM := TOP_FRAME_RIM * FRAME_SCALE
const FRAME_INNER_RIM := TOP_FRAME_INNER_RIM * FRAME_SCALE
const HP_ROW_SIZE := Vector2(92.0, 28.0)
const HP_ROW_Y := FRAME_SIZE + 30.0
const PORTRAIT_SIZE := 115.5
const PORTRAIT_RISE := 16.5
const NORMAL_TEXT_COLOR := Color("#F2E8CC")
const MUTED_TEXT_COLOR := Color("#D7E1EA")
const ORNAMENT_UNDERLAY := Color(0.07, 0.04, 0.02, 0.88)
const HOVER_MODULATE := Color(1.12, 1.12, 1.12, 1.0)
## 必须高于战斗状态行与悬停说明框；暗幕因此统一压暗全部既有 HUD，不留亮着的 Buff。
const OVERLAY_Z_INDEX := 120

signal selection_made(slot: int)

@onready var _prompt: Label = $PromptLabel
@onready var _card_container: HBoxContainer = $CardContainer

var _default_slot: int = -1
var _committing: bool = false
var _prompt_ornaments: Control
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	z_index = OVERLAY_Z_INDEX
	FontManager.apply(_prompt, 32)
	_prompt.add_theme_color_override("font_color", NORMAL_TEXT_COLOR)
	_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.92))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt_ornaments = RoundLabelOrnamentsComponent.new()
	_prompt_ornaments.name = "TitleOrnaments"
	_prompt.add_child(_prompt_ornaments)
	_prompt_ornaments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_ornaments.call("configure", NORMAL_TEXT_COLOR, ORNAMENT_UNDERLAY, 3.0)
	visible = false


## reserves 每项为 [slot_idx:int, hero:HeroData, hp:float]。
func show_selection(player: int, reserves: Array, title: String = "选择出战英雄") -> void:
	_prompt.text = tr(title)

	for child in _card_container.get_children():
		_card_container.remove_child(child)
		child.queue_free()

	_default_slot = int(reserves[0][0]) if reserves.size() > 0 else -1
	_committing = false
	_hover_tweens.clear()

	var player_color := Color("#3F86C8") if player == 0 else Color("#D24A44")
	for entry in reserves:
		var slot_idx: int = int(entry[0])
		var hero: HeroData = entry[1]
		var hp: float = float(entry[2])
		_card_container.add_child(_create_frame_entry(hero, hp, slot_idx, player_color))

	visible = true
	_prompt_ornaments.call("refresh")


## 由 BattleScreen 顶部统一倒计时归零时调用；浮层不再拥有独立 Timer/Label。
func select_default() -> void:
	_commit_selection(_default_slot)


func _create_frame_entry(
		hero: HeroData, hp: float, slot: int, player_color: Color) -> Control:
	var wrap := Control.new()
	wrap.name = "Choice_%d" % slot
	wrap.custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE + 70.0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := HeroFrameScene.instantiate() as HeroFrame
	wrap.add_child(frame)
	frame.position = Vector2.ZERO
	frame.hero_name = hero.hero_name
	frame.player_color = player_color
	frame.flip_h = player_color.r > player_color.b
	frame.frame_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	frame.diamond_mode = true
	frame.diamond_portrait_px = PORTRAIT_SIZE
	frame.diamond_portrait_rise = PORTRAIT_RISE
	frame.diamond_stroke_px = FRAME_STROKE
	frame.diamond_rim_px = FRAME_RIM
	frame.diamond_inner_rim_px = FRAME_INNER_RIM
	frame.bottom_shadow_enabled = true
	frame.portrait_path = hero.portrait_path
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.mouse_entered.connect(_on_frame_hover.bind(frame, true))
	frame.mouse_exited.connect(_on_frame_hover.bind(frame, false))
	frame.gui_input.connect(_on_frame_input.bind(slot, frame))

	var name_label := Label.new()
	name_label.name = "HeroName"
	name_label.text = hero.hero_name
	name_label.position = Vector2(0.0, FRAME_SIZE + 5.0)
	name_label.size = Vector2(FRAME_SIZE, 24.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FontManager.apply(name_label, 18)
	name_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(name_label)

	var hp_row := ReserveHpRowScript.new() as ReserveHpRow
	hp_row.name = "HpRow"
	# 与顶部替补血量使用同一 92x28 版心和现役数字投影，避免死亡换人保留旧宽框比例。
	hp_row.position = Vector2((FRAME_SIZE - HP_ROW_SIZE.x) * 0.5, HP_ROW_Y)
	hp_row.size = HP_ROW_SIZE
	hp_row.icon_slant = -3.0 if player_color.b >= player_color.r else 3.0
	hp_row.bottom_shadow_enabled = true
	hp_row.set_values(hp, 0.0)
	wrap.add_child(hp_row)

	return wrap


func _on_frame_hover(frame: HeroFrame, hovering: bool) -> void:
	if _committing or not is_instance_valid(frame):
		return
	var key := frame.get_instance_id()
	var previous: Tween = _hover_tweens.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := create_tween().set_parallel(true)
	_hover_tweens[key] = tween
	tween.tween_property(
		frame, "position", Vector2(0.0, -2.0) if hovering else Vector2.ZERO, 0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		frame, "modulate", HOVER_MODULATE if hovering else Color.WHITE, 0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_frame_input(event: InputEvent, slot: int, frame: HeroFrame) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			frame.is_selected = true
			_commit_selection(slot, true)


func _commit_selection(slot: int, show_click_feedback: bool = false) -> void:
	if _committing or slot < 0:
		return
	_committing = true
	if show_click_feedback:
		# 规则信号立即发出；浮层只多保留极短一拍，让 HeroFrame 选中反馈真实渲染。
		get_tree().create_timer(0.07).timeout.connect(_hide_after_click_feedback)
	else:
		visible = false
	selection_made.emit(slot)


func _hide_after_click_feedback() -> void:
	visible = false
