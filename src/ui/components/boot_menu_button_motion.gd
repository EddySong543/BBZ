class_name BootMenuButtonMotion
extends Node

enum PresentationMode {
	MAIN_TEXT,
	ICON,
}

const FOCUS_SHADER := preload(
	"res://assets/shaders/canvas_ui_boot_menu_focus.gdshader")
const ICON_FOCUS_COLOR := Color(1.0, 0.86, 0.54, 1.0)
const ICON_FOCUS_TINT_STRENGTH := 0.14
const FOCUS_TIME: float = 0.09
const PRESS_TIME: float = 0.045
const RELEASE_TIME: float = 0.09

@export var presentation_mode: PresentationMode = PresentationMode.MAIN_TEXT
@export var icon_base_path: NodePath
@export var focus_mark_path: NodePath

var focus_strength: float = 0.0:
	set(value):
		focus_strength = clampf(value, 0.0, 1.0)
		_sync_visual_state()
var press_strength: float = 0.0:
	set(value):
		press_strength = clampf(value, 0.0, 1.0)
		_sync_visual_state()
var _button: Button
var _icon_base: BootIconBase
var _focus_mark: Control
var _hovering: bool = false
var _focused: bool = false
var _pressing: bool = false
var _focus_tween: Tween
var _press_tween: Tween
var _material: ShaderMaterial


func _ready() -> void:
	var parent := get_parent()
	if not parent is Button:
		push_error("BootMenuButtonMotion must be a child of Button.")
		return
	_button = parent as Button
	if not icon_base_path.is_empty():
		_icon_base = get_node_or_null(icon_base_path) as BootIconBase
	if not focus_mark_path.is_empty():
		_focus_mark = get_node_or_null(focus_mark_path) as Control
	_material = ShaderMaterial.new()
	_material.shader = FOCUS_SHADER
	_material.resource_local_to_scene = true
	_material.set_shader_parameter(
		&"focus_color",
		ICON_FOCUS_COLOR)
	_material.set_shader_parameter(
		&"focus_tint_strength",
		0.0
		if presentation_mode == PresentationMode.MAIN_TEXT
		else ICON_FOCUS_TINT_STRENGTH)
	_button.material = _material
	_button.pivot_offset = _button.size * 0.5
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_connect_signals()
	_sync_visual_state()


func _connect_signals() -> void:
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.focus_entered.connect(_on_focus_entered)
	_button.focus_exited.connect(_on_focus_exited)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.resized.connect(_on_resized)


func _on_mouse_entered() -> void:
	if _button.disabled:
		return
	_hovering = true
	_apply_focus_target()


func _on_mouse_exited() -> void:
	_hovering = false
	_pressing = false
	_apply_focus_target()
	_apply_press_target()


func _on_focus_entered() -> void:
	_focused = true
	_apply_focus_target()


func _on_focus_exited() -> void:
	_focused = false
	_apply_focus_target()


func _on_button_down() -> void:
	if _button.disabled:
		return
	_pressing = true
	_apply_press_target()


func _on_button_up() -> void:
	_pressing = false
	_apply_press_target()


func _on_resized() -> void:
	if _button != null:
		_button.pivot_offset = _button.size * 0.5
	_sync_visual_state()


func _apply_focus_target() -> void:
	var active: bool = (_hovering or _focused) and not _button.disabled
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(
		self,
		"focus_strength",
		1.0 if active else 0.0,
		FOCUS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_press_target() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(
		self,
		"press_strength",
		1.0 if _pressing else 0.0,
		PRESS_TIME if _pressing else RELEASE_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _sync_visual_state() -> void:
	if _button == null or _material == null:
		return
	var focus_scale: float = (
		1.03
		if presentation_mode == PresentationMode.MAIN_TEXT
		else 1.0)
	var press_scale: float = (
		0.97
		if presentation_mode == PresentationMode.MAIN_TEXT
		else 1.0)
	var target_scale: float = lerpf(1.0, focus_scale, focus_strength)
	target_scale = lerpf(target_scale, press_scale, press_strength)
	_button.scale = Vector2.ONE * target_scale
	_button.pivot_offset = _button.size * 0.5
	var offset := Vector2.ZERO
	if presentation_mode == PresentationMode.MAIN_TEXT:
		offset.x = focus_strength * 4.0
		offset.y += press_strength
	else:
		var focus_step: int = clampi(
			floori(focus_strength * 2.0 + 0.5) * 2,
			0,
			4)
		var press_step: int = clampi(
			floori(press_strength * 2.0 + 0.5) * 2,
			0,
			4)
		offset.y = float(-focus_step + press_step)
	_material.set_shader_parameter(&"visual_offset", offset)
	_material.set_shader_parameter(&"focus_strength", focus_strength)
	_material.set_shader_parameter(&"press_strength", press_strength)
	if _icon_base != null:
		_icon_base.set_state(focus_strength, press_strength)
	if _focus_mark != null:
		_focus_mark.call(&"set_state", focus_strength, press_strength)


func debug_state() -> Dictionary:
	var visual_offset := Vector2.ZERO
	if _material != null:
		visual_offset = Vector2(
			_material.get_shader_parameter(&"visual_offset"))
	return {
		"focus_strength": focus_strength,
		"press_strength": press_strength,
		"visual_offset": visual_offset,
		"scale": _button.scale if _button != null else Vector2.ONE,
		"presentation_mode": presentation_mode,
		"icon_base_path": icon_base_path,
		"focus_mark_path": focus_mark_path,
		"focus_color": (
			_material.get_shader_parameter(&"focus_color")
			if _material != null else Color.TRANSPARENT),
		"focus_tint_strength": (
			float(_material.get_shader_parameter(&"focus_tint_strength"))
			if _material != null else 0.0),
		"sweep_enabled": false,
	}
