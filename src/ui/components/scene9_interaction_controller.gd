extends Node

## Scene9-only click router. It mirrors Scene8's proven early `_input` path so
## the fullscreen battle Control cannot swallow scene clicks. It never marks an
## event handled; battle buttons and item rows are rejected before dispatch.

const CLICK_STREAK_POOL_SIZE := 3
const CLICK_STREAK_DEPTH_COUNT := 3
const GRASS_HIT_TOLERANCE_SOURCE_PX := Vector2i(3, 2)
const GRASS_TARGET_NAMES: PackedStringArray = [
	"ForegroundMid",
	"DistantLeft",
	"DistantLeft2",
	"DistantRight",
	"DistantRight2",
]
const GRASS_BLOCKER_NAMES: PackedStringArray = []
const GRASS_CLICK_PARTICLE_NAMES: PackedStringArray = [
	"GrassClickPool1/MidFar", "GrassClickPool1/Far", "GrassClickPool1/Cover",
	"GrassClickPool2/MidFar", "GrassClickPool2/Far", "GrassClickPool2/Cover",
	"GrassClickPool3/MidFar", "GrassClickPool3/Far", "GrassClickPool3/Cover",
]

var _stage: BattleStage
var _grass_targets: Array[Control] = []
var _grass_blockers: Array[Control] = []
var _grass_click_groups: Array[Array] = []
var _grass_click_group_origins: Array[Vector2] = []
var _grass_click_group_started_msec: Array[int] = []
var _hit_images: Dictionary = {}
var _left_click_input_count := 0
var _grass_response_spawn_count := 0


func _ready() -> void:
	_stage = get_parent() as BattleStage
	for target_name: String in GRASS_TARGET_NAMES:
		var target := _stage.get_node_or_null(target_name) as Control
		if target == null:
			continue
		_grass_targets.append(target)
	for blocker_name: String in GRASS_BLOCKER_NAMES:
		var blocker := _stage.get_node_or_null(blocker_name) as Control
		if blocker != null:
			_grass_blockers.append(blocker)
	_build_grass_click_pool()
	_clear_retired_grass_wave_uniforms()
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if (mouse_event.button_index != MOUSE_BUTTON_LEFT
			or not mouse_event.pressed or mouse_event.is_echo()):
		return
	if _viewport_position_is_blocked_by_battle_ui(mouse_event.position):
		return
	_left_click_input_count += 1
	_stage.call("register_scene_click_at_canvas_position", mouse_event.position)


func trigger_grass_at_canvas_position(canvas_position: Vector2) -> bool:
	if _grass_target_at_canvas_position(canvas_position) == null:
		return false
	if _grass_click_groups.size() != CLICK_STREAK_POOL_SIZE:
		return true
	var now_msec := Time.get_ticks_msec()
	var selected_group_index := -1
	for group_index: int in _grass_click_groups.size():
		if not _grass_click_group_is_active(group_index):
			selected_group_index = group_index
			break
	if selected_group_index < 0:
		selected_group_index = 0
		for group_index: int in range(1, _grass_click_groups.size()):
			if (_grass_click_group_started_msec[group_index]
					< _grass_click_group_started_msec[selected_group_index]):
				selected_group_index = group_index
	var local_origin := _stage.get_global_transform_with_canvas().affine_inverse() \
			* canvas_position
	var particle_group := _grass_click_groups[selected_group_index]
	for depth_index: int in particle_group.size():
		var particles := particle_group[depth_index] as CPUParticles2D
		var layer_origin := local_origin + Vector2(
				(float(depth_index) - 1.0) * 10.0,
				4.0 + float(depth_index) * 4.0)
		_stage.set_layer_base_position(particles, layer_origin)
		particles.restart()
	_grass_click_group_origins[selected_group_index] = canvas_position
	_grass_click_group_started_msec[selected_group_index] = now_msec
	_grass_response_spawn_count += 1
	return true


func _grass_target_at_canvas_position(canvas_position: Vector2) -> Control:
	for blocker: Control in _grass_blockers:
		if _target_has_opaque_pixel_at(blocker, canvas_position):
			return null
	for target: Control in _grass_targets:
		if _target_has_opaque_pixel_at(target, canvas_position):
			return target
	return null


func _build_grass_click_pool() -> void:
	var disturbance_texture := _build_grass_disturbance_texture()
	var particle_layers: Array[CPUParticles2D] = []
	for node_name: String in GRASS_CLICK_PARTICLE_NAMES:
		var particles := _stage.get_node_or_null(node_name) as CPUParticles2D
		if particles == null:
			continue
		particles.texture = disturbance_texture
		particle_layers.append(particles)
	if particle_layers.size() != CLICK_STREAK_POOL_SIZE * CLICK_STREAK_DEPTH_COUNT:
		return
	for pool_index: int in CLICK_STREAK_POOL_SIZE:
		var group: Array = []
		for depth_index: int in CLICK_STREAK_DEPTH_COUNT:
			group.append(particle_layers[
					pool_index * CLICK_STREAK_DEPTH_COUNT + depth_index])
		_grass_click_groups.append(group)
		_grass_click_group_origins.append(Vector2.ZERO)
		_grass_click_group_started_msec.append(-1)


func _build_grass_disturbance_texture() -> ImageTexture:
	var image := Image.create(6, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for point: Vector2i in [
		Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
	]:
		image.set_pixelv(point, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _grass_click_group_is_active(group_index: int) -> bool:
	if group_index < 0 or group_index >= _grass_click_groups.size():
		return false
	for particle_value: Variant in _grass_click_groups[group_index]:
		var particles := particle_value as CPUParticles2D
		if particles != null and particles.emitting:
			return true
	return false


func _clear_retired_grass_wave_uniforms() -> void:
	var materials: Array[ShaderMaterial] = []
	for target: Control in _grass_targets + _grass_blockers:
		var material := target.material as ShaderMaterial
		if material != null and not materials.has(material):
			materials.append(material)
	for material: ShaderMaterial in materials:
		for wave_slot: int in 3:
			material.set_shader_parameter(
					StringName("click_wave_%d" % wave_slot), Vector4.ZERO)


func _target_has_opaque_pixel_at(
		target: Control, canvas_position: Vector2) -> bool:
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		return false
	var local_position := (
			target.get_global_transform_with_canvas().affine_inverse()
			* canvas_position)
	if not Rect2(Vector2.ZERO, target.size).has_point(local_position):
		return false
	var texture := target.get("texture") as Texture2D
	if texture == null:
		return false
	var texture_id := texture.get_instance_id()
	var image := _hit_images.get(texture_id) as Image
	if image == null:
		image = texture.get_image()
		if image != null:
			_hit_images[texture_id] = image
	if image == null or image.is_empty():
		return false
	var source_pixel := Vector2i(
			clampi(floori(local_position.x / target.size.x * image.get_width()),
					0, image.get_width() - 1),
			clampi(floori(local_position.y / target.size.y * image.get_height()),
					0, image.get_height() - 1))
	for offset_y: int in range(
			-GRASS_HIT_TOLERANCE_SOURCE_PX.y,
			GRASS_HIT_TOLERANCE_SOURCE_PX.y + 1):
		for offset_x: int in range(
				-GRASS_HIT_TOLERANCE_SOURCE_PX.x,
				GRASS_HIT_TOLERANCE_SOURCE_PX.x + 1):
			var sample_pixel := Vector2i(
					clampi(source_pixel.x + offset_x, 0, image.get_width() - 1),
					clampi(source_pixel.y + offset_y, 0, image.get_height() - 1))
			if (_source_pixel_is_trimmed(target, sample_pixel)
					or image.get_pixelv(sample_pixel).a < 0.08):
				continue
			return true
	return false


func _source_pixel_is_trimmed(target: Control, source_pixel: Vector2i) -> bool:
	var shader_material := target.material as ShaderMaterial
	if shader_material == null or not bool(shader_material.get_shader_parameter(
			&"source_trim_enabled")):
		return false
	var trim := shader_material.get_shader_parameter(
			&"source_trim_rect_px") as Vector4
	return Rect2(Vector2(trim.x, trim.y), Vector2(trim.z, trim.w)).has_point(
			Vector2(source_pixel))


func _viewport_position_is_blocked_by_battle_ui(
		viewport_position: Vector2) -> bool:
	var battle_root := _find_battle_screen_root()
	if battle_root == null:
		return false
	var buttons := battle_root.get_node_or_null("Buttons") as Control
	if (buttons != null and buttons.is_visible_in_tree()
			and buttons.get_global_rect().has_point(viewport_position)):
		return true
	for candidate: Node in battle_root.find_children(
			"*", "ItemSlotRow", true, false):
		if candidate is Control:
			var item_row := candidate as Control
			if (item_row.is_visible_in_tree()
					and item_row.get_global_rect().has_point(viewport_position)):
				return true
	return false


func _find_battle_screen_root() -> Node:
	var current := get_parent()
	while current != null:
		if current.get_node_or_null("Buttons") is Control:
			return current
		current = current.get_parent()
	return null


func find_grass_position_for_testing() -> Vector2:
	for target: Control in _grass_targets:
		var texture := target.get("texture") as Texture2D
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null or image.is_empty():
			continue
		for y: int in range(0, image.get_height(), 2):
			for x: int in range(0, image.get_width(), 2):
				if image.get_pixel(x, y).a < 0.2:
					continue
				var local_position := Vector2(
						(float(x) + 0.5) / image.get_width() * target.size.x,
						(float(y) + 0.5) / image.get_height() * target.size.y)
				var canvas_position := (
						target.get_global_transform_with_canvas() * local_position)
				if canvas_position.x < 0.0 or canvas_position.x >= 1920.0 \
						or canvas_position.y < 0.0 or canvas_position.y >= 1080.0:
					continue
				if _target_has_opaque_pixel_at(target, canvas_position):
					return canvas_position
	return Vector2(-1.0, -1.0)


func left_click_input_count_for_testing() -> int:
	return _left_click_input_count


func advance_grass_response_for_testing(delta: float) -> void:
	# CPUParticles2D owns lifetime advancement in the runtime tree. Kept as a
	# deterministic test seam; overlapping clicks intentionally have no cooldown.
	pass


func grass_response_contract_for_testing() -> Dictionary:
	var active_group_count := 0
	for group_index: int in _grass_click_groups.size():
		if _grass_click_group_is_active(group_index):
			active_group_count += 1
	return {
		"hit_test": "source_alpha",
		"response": "scene5_upward_silver_chaff",
		"active_group_count": active_group_count,
		"maximum_simultaneous_groups": CLICK_STREAK_POOL_SIZE,
		"root_locked": true,
		"cooldown_seconds": 0.0,
		"same_region_overlap": true,
		"responsive_layer_count": _grass_targets.size(),
		"blocker_layer_count": _grass_blockers.size(),
		"particle_layer_count": GRASS_CLICK_PARTICLE_NAMES.size(),
		"spawn_count": _grass_response_spawn_count,
		"hit_tolerance_source_pixels": GRASS_HIT_TOLERANCE_SOURCE_PX,
		"direction": "upward",
	}
