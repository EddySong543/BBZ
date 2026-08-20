class_name Scene4ClickTarget
extends TextureRect

@export var interaction_controller_path := NodePath("../ClickInteraction")
@export var interaction_target_name: StringName
@export_range(0.01, 0.8, 0.01) var alpha_hit_threshold := 0.12

var _source_image: Image


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if texture != null:
		_source_image = texture.get_image()


func _has_point(point: Vector2) -> bool:
	if _source_image == null or _source_image.is_empty():
		return false
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	var uv := point / size
	if flip_h:
		uv.x = 1.0 - uv.x
	if flip_v:
		uv.y = 1.0 - uv.y
	var pixel := Vector2i(
			clampi(int(floor(uv.x * _source_image.get_width())),
					0, _source_image.get_width() - 1),
			clampi(int(floor(uv.y * _source_image.get_height())),
					0, _source_image.get_height() - 1))
	return _source_image.get_pixelv(pixel).a >= alpha_hit_threshold


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var controller := get_node_or_null(interaction_controller_path)
	if controller == null or not controller.has_method("trigger_target"):
		return
	if bool(controller.call("trigger_target", interaction_target_name)):
		accept_event()
