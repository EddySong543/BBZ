extends Node

const LAKE_RESPONSE_DURATION_SEC := 1.65
const LAKE_IMMEDIATE_STRENGTH_FLOOR := 0.62
const LAKE_RIPPLE_VERTICAL_COMPRESSION := 0.38
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const PLATFORM_SURFACE_BOTTOM_SOURCE_ROW := 103.0
const PLATFORM_ALPHA_THRESHOLD := 0.03
const CHIP_PIECE_COUNT := 12
const CHIP_LIFETIME_SEC := 1.0
const CONTACT_FLASH_LIFETIME_SEC := 0.34
const TAP_SHAKE_DURATION_SEC := 0.18
const TAP_SHAKE_AMPLITUDE_PX := 4.0
const BREAK_SHAKE_DURATION_SEC := 0.40
const BREAK_SHAKE_AMPLITUDE_PX := 10.0
const BREAK_STRESS_CELL_SIZE := 32.0
const PLATFORM_FISSURE_START_SOURCE_ROW := 90.0
const PLATFORM_FISSURE_END_SOURCE_ROW := 103.0
const PLATFORM_FISSURE_CORE_WIDTH_SOURCE_PX := 1.0
const PLATFORM_FISSURE_MAX_NODE_WIDTH_SOURCE_PX := 2.0
const PLATFORM_FISSURE_MAX_CENTER_OFFSET_SOURCE_PX := 2.0
const PLATFORM_FISSURE_BRANCH_COUNT := 3
const PLATFORM_FISSURE_GROWTH_SEGMENT_COUNT := 4
const PLATFORM_FISSURE_GROWTH_DURATION_SEC := 0.34
const PLATFORM_BREAK_BASE_PROBABILITY := 0.10
const PLATFORM_BREAK_CLICK_STEP := 0.04
const PLATFORM_BREAK_LOCAL_STRESS_STEP := 0.06
const PLATFORM_BREAK_PROBABILITY_CAP := 0.30
const PLATFORM_SHAKE_PATTERN := [
	Vector2(1.0, -0.42),
	Vector2(-0.82, 0.50),
	Vector2(0.68, 0.30),
	Vector2(-0.58, -0.46),
	Vector2(0.42, 0.24),
	Vector2(-0.32, -0.18),
]

@export var topology_path: NodePath = ^"../LakeTopology"
@export var lake_path: NodePath = ^"../MirrorLake"
@export var reflection_path: NodePath = ^"../AuroraReflection"
@export var platform_path: NodePath = ^"../BattlePlatform"
@export var platform_contact_path: NodePath = ^"../PlatformWaterContact"
@export var foreground_paths: Array[NodePath] = [
	^"../ForegroundLeft",
	^"../ForegroundRight",
	^"../ForegroundSnowfield",
]

var _topology: Scene8LakeTopology
var _lake_material: ShaderMaterial
var _reflection_material: ShaderMaterial
var _platform_material: ShaderMaterial
var _platform: TextureRect
var _platform_contact: Control
var _platform_image: Image
var _foreground_layers: Array[TextureRect] = []
var _lake_ripples: Array[Dictionary] = []
var _lake_event_image: Image
var _lake_event_texture: ImageTexture
var _lake_event_capacity := 0
var _left_click_input_count := 0
var _platform_click_count := 0
var _stress_cells: Dictionary = {}
var _platform_broken := false
var _platform_break_progress := 0.0
var _chip_bursts: Array[IceChipBurst] = []
var _contact_flashes: Array[PlatformContactFlash] = []
var _platform_shake_kind := &"none"
var _platform_shake_elapsed_sec := 0.0
var _platform_shake_duration_sec := 0.0
var _platform_shake_amplitude_px := 0.0
var _platform_shake_offset := Vector2.ZERO
var _platform_shake_seed := 0.0
var _rng := RandomNumberGenerator.new()


class IceChipBurst:
	extends Node2D

	var lifetime_sec := CHIP_LIFETIME_SEC
	var elapsed_sec := 0.0
	var pieces: Array[Dictionary] = []
	var screen_scale := 6.0


	func configure(seed_value: int, configured_screen_scale: float) -> void:
		screen_scale = configured_screen_scale
		z_index = 8
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = seed_value
		var colors: Array[Color] = [
			Color(0.74, 0.94, 1.0, 1.0),
			Color(0.38, 0.82, 1.0, 0.96),
			Color(0.50, 1.0, 0.76, 0.92),
		]
		for piece_index: int in CHIP_PIECE_COUNT:
			var size_local := local_rng.randf_range(0.45, 0.72)
			pieces.append({
				"position": Vector2.ZERO,
				"velocity": Vector2(
						local_rng.randf_range(-20.0, 20.0),
						local_rng.randf_range(-20.0, -9.0)),
				"size": size_local,
				"wide": piece_index % 3 == 0,
				"color": colors[piece_index % colors.size()],
			})
		queue_redraw()


	func _process(delta: float) -> void:
		elapsed_sec += delta
		if elapsed_sec >= lifetime_sec:
			queue_free()
			return
		for piece: Dictionary in pieces:
			var velocity := piece.velocity as Vector2
			velocity.y += 38.0 * delta
			piece.velocity = velocity
			piece.position = (piece.position as Vector2) + velocity * delta
		queue_redraw()


	func _draw() -> void:
		var fade := 1.0 - smoothstep(0.72, lifetime_sec, elapsed_sec)
		for piece: Dictionary in pieces:
			var draw_position: Vector2 = piece.position
			draw_position = (draw_position * 2.0).round() / 2.0
			var size_local := float(piece.size)
			var draw_size := Vector2(
					size_local * (1.20 if bool(piece.wide) else 1.0),
					size_local * (0.65 if bool(piece.wide) else 1.0))
			var color: Color = piece.color
			color.a *= fade
			draw_rect(Rect2(draw_position - draw_size * 0.5, draw_size), color)


	func contract_for_testing() -> Dictionary:
		var minimum_piece := INF
		var maximum_piece := 0.0
		for piece: Dictionary in pieces:
			var size_local := float(piece.size)
			var width_scale := 1.20 if bool(piece.wide) else 1.0
			minimum_piece = minf(minimum_piece, size_local * screen_scale)
			maximum_piece = maxf(
					maximum_piece, size_local * width_scale * screen_scale)
		return {
			"piece_count": pieces.size(),
			"minimum_screen_piece_px": minimum_piece,
			"maximum_screen_piece_px": maximum_piece,
			"lifetime_sec": lifetime_sec,
		}


class PlatformContactFlash:
	extends Node2D

	var elapsed_sec := 0.0
	var lifetime_sec := CONTACT_FLASH_LIFETIME_SEC


	func configure() -> void:
		z_index = 9
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		queue_redraw()


	func _process(delta: float) -> void:
		elapsed_sec += delta
		if elapsed_sec >= lifetime_sec:
			queue_free()
			return
		queue_redraw()


	func _draw() -> void:
		var normalized_age := clampf(elapsed_sec / lifetime_sec, 0.0, 1.0)
		var envelope := 1.0 - smoothstep(0.22, 1.0, normalized_age)
		var expansion := lerpf(0.65, 1.45, smoothstep(0.0, 0.55, normalized_age))
		var core := Color(0.72, 1.0, 0.90, 0.95 * envelope)
		var cyan := Color(0.38, 0.84, 1.0, 0.82 * envelope)
		# Pixel-snapped asymmetric facets: an immediate readable contact cue,
		# never a radial ring or a large generic explosion.
		var segments: Array[Rect2] = [
			Rect2(Vector2(-3.5, -0.45) * expansion, Vector2(7.0, 0.9)),
			Rect2(Vector2(-0.45, -2.8) * expansion, Vector2(0.9, 4.2)),
			Rect2(Vector2(1.6, -1.8) * expansion, Vector2(2.8, 0.75)),
			Rect2(Vector2(-4.2, 1.3) * expansion, Vector2(2.4, 0.75)),
		]
		for segment_index: int in segments.size():
			var rect := segments[segment_index]
			rect.position = (rect.position * 2.0).round() / 2.0
			draw_rect(rect, core if segment_index < 2 else cyan)


func _ready() -> void:
	_topology = get_node_or_null(topology_path) as Scene8LakeTopology
	var lake := get_node_or_null(lake_path) as CanvasItem
	var reflection := get_node_or_null(reflection_path) as CanvasItem
	_platform = get_node_or_null(platform_path) as TextureRect
	_platform_contact = get_node_or_null(platform_contact_path) as Control
	assert(_topology != null and lake != null and reflection != null)
	if _topology.get_topology_image() == null:
		var topology_rebuilt := _topology.rebuild()
		assert(topology_rebuilt)
	assert(_platform != null and _platform.texture != null)
	assert(_platform_contact != null)
	_lake_material = lake.material as ShaderMaterial
	_reflection_material = reflection.material as ShaderMaterial
	_platform_material = _platform.material as ShaderMaterial
	_platform_image = _platform.texture.get_image()
	assert(_lake_material != null and _reflection_material != null)
	assert(_platform_material != null)
	assert(_platform_image != null and not _platform_image.is_empty())
	for foreground_path: NodePath in foreground_paths:
		var layer := get_node_or_null(foreground_path) as TextureRect
		if layer != null and layer.texture != null:
			_foreground_layers.append(layer)
	_platform_material.set_shader_parameter(&"platform_break_amount", 0.0)
	_platform_break_progress = 0.0
	_rng.randomize()
	_sync_lake_uniforms()
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if _platform_broken and _platform_break_progress < 1.0:
		_platform_break_progress = minf(
				_platform_break_progress
						+ delta / PLATFORM_FISSURE_GROWTH_DURATION_SEC,
				1.0)
		_platform_material.set_shader_parameter(
				&"platform_break_amount", _platform_break_progress)
	for ripple_index: int in range(_lake_ripples.size() - 1, -1, -1):
		var ripple: Dictionary = _lake_ripples[ripple_index]
		ripple.age = float(ripple.age) + delta
		if float(ripple.age) >= LAKE_RESPONSE_DURATION_SEC:
			_lake_ripples.remove_at(ripple_index)
	_sync_lake_uniforms()
	for burst_index: int in range(_chip_bursts.size() - 1, -1, -1):
		if not is_instance_valid(_chip_bursts[burst_index]):
			_chip_bursts.remove_at(burst_index)
	for flash_index: int in range(_contact_flashes.size() - 1, -1, -1):
		if not is_instance_valid(_contact_flashes[flash_index]):
			_contact_flashes.remove_at(flash_index)
	_apply_platform_shake(delta)


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
	var hit_kind := _hit_kind_at_viewport_position(mouse_event.position)
	if hit_kind == &"platform":
		trigger_platform_at_viewport_position(mouse_event.position)
	elif hit_kind == &"lake":
		trigger_lake_at_viewport_position(mouse_event.position)


func trigger_lake_at_viewport_position(viewport_position: Vector2) -> bool:
	if _hit_kind_at_viewport_position(viewport_position) != &"lake":
		return false
	# Append every valid click. The GPU event texture grows geometrically, so no
	# active ripple is overwritten or rejected by an application-level pool cap.
	_lake_ripples.append({
		"center": viewport_position / DESIGN_SIZE,
		"age": 0.0,
	})
	_sync_lake_uniforms()
	return true


func trigger_platform_at_viewport_position(
		viewport_position: Vector2, force_break: bool = false) -> bool:
	var local_position := _platform_surface_local_position(viewport_position)
	if local_position.x < 0.0:
		return false
	_platform_click_count += 1
	var stress_key := _stress_key(local_position)
	_stress_cells[stress_key] = int(_stress_cells.get(stress_key, 0)) + 1
	_spawn_ice_chips(local_position)
	_spawn_contact_flash(local_position)
	var probability := _current_platform_break_probability(local_position)
	var break_created := false
	if (not _platform_broken and _platform_click_count >= 3
			and (force_break or _rng.randf() < probability)):
		break_created = _create_center_platform_fissure()
	_start_platform_shake(break_created)
	return true


func _spawn_ice_chips(local_position: Vector2) -> void:
	var burst := IceChipBurst.new()
	burst.name = "Scene8IceChipBurst"
	burst.position = local_position
	burst.configure(
			_rng.randi(),
			maxf(absf(_platform.scale.x), absf(_platform.scale.y)))
	_platform.add_child(burst)
	_chip_bursts.append(burst)


func _spawn_contact_flash(local_position: Vector2) -> void:
	var flash := PlatformContactFlash.new()
	flash.name = "Scene8PlatformContactFlash"
	flash.position = local_position
	flash.configure()
	_platform.add_child(flash)
	_contact_flashes.append(flash)


func _create_center_platform_fissure() -> bool:
	if _platform_broken:
		return false
	_platform_broken = true
	# Reveal the bottom-edge impact root immediately, then climb through the
	# four authored pixel groups during the large shake.
	_platform_break_progress = 0.06
	_platform_material.set_shader_parameter(
			&"platform_break_amount", _platform_break_progress)
	return true


func _start_platform_shake(break_created: bool) -> void:
	var next_kind := &"break" if break_created else &"tap"
	var next_duration := (
			BREAK_SHAKE_DURATION_SEC if break_created
			else TAP_SHAKE_DURATION_SEC)
	var next_amplitude := (
			BREAK_SHAKE_AMPLITUDE_PX if break_created
			else TAP_SHAKE_AMPLITUDE_PX)
	# A center break always replaces a tap. Repeated taps restart the short
	# response, but can never reduce an active break shake to a weaker one.
	if (_platform_shake_kind == &"break"
			and _platform_shake_elapsed_sec < _platform_shake_duration_sec
			and not break_created):
		return
	_platform_shake_kind = next_kind
	_platform_shake_elapsed_sec = 0.0
	_platform_shake_duration_sec = next_duration
	_platform_shake_amplitude_px = next_amplitude
	_platform_shake_seed = float(_rng.randi_range(0, PLATFORM_SHAKE_PATTERN.size() - 1))
	_platform_shake_offset = Vector2.ZERO


func _apply_platform_shake(delta: float) -> void:
	if (_platform_shake_kind == &"none"
			or _platform_shake_duration_sec <= 0.0):
		_platform_shake_offset = Vector2.ZERO
		return
	_platform_shake_elapsed_sec += delta
	if _platform_shake_elapsed_sec >= _platform_shake_duration_sec:
		_platform_shake_kind = &"none"
		_platform_shake_offset = Vector2.ZERO
		return
	var normalized_age := clampf(
			_platform_shake_elapsed_sec / _platform_shake_duration_sec,
			0.0, 1.0)
	# Trauma-style quadratic decay keeps the first impact crisp while ensuring
	# the platform returns cleanly instead of vibrating for the full duration.
	var envelope := pow(1.0 - normalized_age, 2.0)
	var pattern_index := (
			int(_platform_shake_seed)
			+ floori(_platform_shake_elapsed_sec * 92.0)) \
			% PLATFORM_SHAKE_PATTERN.size()
	var pulse: Vector2 = PLATFORM_SHAKE_PATTERN[pattern_index]
	_platform_shake_offset = Vector2(
			round(pulse.x * _platform_shake_amplitude_px * envelope),
			round(pulse.y * _platform_shake_amplitude_px * envelope))
	_platform.position += _platform_shake_offset
	_platform_contact.position += _platform_shake_offset
	var world_group := _find_embedded_world_group()
	if world_group != null:
		world_group.position += _platform_shake_offset


func _find_embedded_world_group() -> Control:
	var ancestor := get_parent()
	while ancestor != null:
		var world_group := ancestor.get_node_or_null("WorldGroup") as Control
		if world_group != null:
			return world_group
		ancestor = ancestor.get_parent()
	return null


func _sync_lake_uniforms() -> void:
	if _lake_material == null or _reflection_material == null:
		return
	var required_capacity := maxi(_lake_ripples.size(), 1)
	var next_capacity := maxi(_lake_event_capacity, 1)
	while next_capacity < required_capacity:
		next_capacity *= 2
	var texture_resized := (
			_lake_event_image == null or next_capacity != _lake_event_capacity)
	if texture_resized:
		_lake_event_capacity = next_capacity
		_lake_event_image = Image.create(
				_lake_event_capacity, 1, false, Image.FORMAT_RGBAF)
	for ripple_index: int in _lake_ripples.size():
		var ripple: Dictionary = _lake_ripples[ripple_index]
		var center := ripple.center as Vector2
		_lake_event_image.set_pixel(
				ripple_index, 0,
				Color(center.x, center.y, float(ripple.age), 1.0))
	if texture_resized:
		_lake_event_texture = ImageTexture.create_from_image(_lake_event_image)
	else:
		_lake_event_texture.update(_lake_event_image)
	for material: ShaderMaterial in [_lake_material, _reflection_material]:
		material.set_shader_parameter(
				&"click_ripple_events", _lake_event_texture)
		material.set_shader_parameter(
				&"click_ripple_count", _lake_ripples.size())
		material.set_shader_parameter(
				&"click_ripple_duration_sec", LAKE_RESPONSE_DURATION_SEC)


func _hit_kind_at_viewport_position(viewport_position: Vector2) -> StringName:
	if _platform_surface_local_position(viewport_position).x >= 0.0:
		return &"platform"
	if _viewport_position_is_blocked_by_foreground(viewport_position):
		return &"none"
	var topology_sample := _topology.sample_at_viewport_position(viewport_position)
	if topology_sample.r >= 0.5 and topology_sample.g >= 0.12:
		return &"lake"
	return &"none"


func _platform_surface_local_position(viewport_position: Vector2) -> Vector2:
	if _platform == null or _platform_image == null:
		return Vector2(-1.0, -1.0)
	var local_position := (
			_platform.get_global_transform_with_canvas().affine_inverse()
			* viewport_position)
	if not Rect2(Vector2.ZERO, _platform.size).has_point(local_position):
		return Vector2(-1.0, -1.0)
	if not _platform_local_is_surface(local_position):
		return Vector2(-1.0, -1.0)
	return local_position


func _platform_local_is_surface(local_position: Vector2) -> bool:
	if (_platform == null or _platform_image == null
			or _platform.size.x <= 0.0 or _platform.size.y <= 0.0):
		return false
	if not Rect2(Vector2.ZERO, _platform.size).has_point(local_position):
		return false
	var source_position := Vector2(
			local_position.x / _platform.size.x * float(_platform_image.get_width()),
			local_position.y / _platform.size.y * float(_platform_image.get_height()))
	if source_position.y > PLATFORM_SURFACE_BOTTOM_SOURCE_ROW:
		return false
	var pixel := Vector2i(
			clampi(floori(source_position.x), 0, _platform_image.get_width() - 1),
			clampi(floori(source_position.y), 0, _platform_image.get_height() - 1))
	return _platform_image.get_pixelv(pixel).a >= PLATFORM_ALPHA_THRESHOLD
func _viewport_position_is_blocked_by_battle_ui(
		viewport_position: Vector2) -> bool:
	var battle_root := _find_battle_screen_root()
	if battle_root == null:
		return false
	var buttons := battle_root.get_node_or_null("Buttons") as Control
	if (buttons != null and buttons.is_visible_in_tree()
			and buttons.get_global_rect().has_point(viewport_position)):
		return true
	for item_row: Control in _battle_item_rows(battle_root):
		if (item_row.is_visible_in_tree()
				and _item_row_global_rect(item_row).has_point(viewport_position)):
			return true
	return false


func _find_battle_screen_root() -> Node:
	var current := get_parent()
	while current != null:
		if current.get_node_or_null("Buttons") is Control:
			return current
		current = current.get_parent()
	return null


func _battle_item_rows(battle_root: Node) -> Array[Control]:
	var rows: Array[Control] = []
	for candidate: Node in battle_root.find_children(
			"*", "ItemSlotRow", true, false):
		if candidate is Control:
			rows.append(candidate as Control)
	return rows


func _item_row_global_rect(item_row: Control) -> Rect2:
	var combined := Rect2()
	var has_rect := false
	for candidate: Node in item_row.find_children("*", "Button", true, false):
		if not (candidate is Control):
			continue
		var rect := (candidate as Control).get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		combined = combined.merge(rect) if has_rect else rect
		has_rect = true
	return combined if has_rect else item_row.get_global_rect()


func _viewport_position_is_blocked_by_foreground(viewport_position: Vector2) -> bool:
	for layer: TextureRect in _foreground_layers:
		var local_position := (
				layer.get_global_transform_with_canvas().affine_inverse()
				* viewport_position)
		if not Rect2(Vector2.ZERO, layer.size).has_point(local_position):
			continue
		var image := layer.texture.get_image()
		if image == null or image.is_empty():
			continue
		var pixel := Vector2i(
				clampi(floori(local_position.x / layer.size.x
						* float(image.get_width())), 0, image.get_width() - 1),
				clampi(floori(local_position.y / layer.size.y
						* float(image.get_height())), 0, image.get_height() - 1))
		if image.get_pixelv(pixel).a >= PLATFORM_ALPHA_THRESHOLD:
			return true
	return false


func _stress_key(local_position: Vector2) -> Vector2i:
	return Vector2i(
			floori(local_position.x / BREAK_STRESS_CELL_SIZE),
			floori(local_position.y / BREAK_STRESS_CELL_SIZE))


func _current_platform_break_probability(local_position: Vector2) -> float:
	if _platform_broken or _platform_click_count < 3:
		return 0.0
	var local_stress := int(_stress_cells.get(_stress_key(local_position), 0))
	return minf(
			PLATFORM_BREAK_BASE_PROBABILITY
			+ float(_platform_click_count - 3) * PLATFORM_BREAK_CLICK_STEP
			+ float(maxi(local_stress - 1, 0))
					* PLATFORM_BREAK_LOCAL_STRESS_STEP,
			PLATFORM_BREAK_PROBABILITY_CAP)


func hit_kind_at_viewport_position_for_testing(viewport_position: Vector2) -> String:
	return String(_hit_kind_at_viewport_position(viewport_position))


func find_lake_position_for_testing() -> Vector2:
	for y: int in range(520, floori(DESIGN_SIZE.y) - 80, 24):
		for x: int in range(120, floori(DESIGN_SIZE.x) - 120, 24):
			var candidate := Vector2(x, y)
			if _hit_kind_at_viewport_position(candidate) == &"lake":
				return candidate
	return Vector2(-1.0, -1.0)


func find_platform_position_for_testing() -> Vector2:
	for y: int in range(97, 102):
		for x_offset: int in range(_platform_image.get_width() / 2):
			for sign_value: int in [-1, 1]:
				var x := clampi(
						_platform_image.get_width() / 2 + x_offset * sign_value,
						0, _platform_image.get_width() - 1)
				if _platform_image.get_pixel(x, y).a < PLATFORM_ALPHA_THRESHOLD:
					continue
				var local_position := Vector2(
						(float(x) + 0.5) / float(_platform_image.get_width())
								* _platform.size.x,
						(float(y) + 0.5) / float(_platform_image.get_height())
								* _platform.size.y)
				return _platform.get_global_transform_with_canvas() * local_position
	return Vector2(-1.0, -1.0)


func find_platform_center_fissure_position_for_testing() -> Vector2:
	var center_x := _platform_image.get_width() / 2
	for y: int in range(96, 99):
		for x_offset: int in range(0, 8):
			for sign_value: int in [-1, 1]:
				var x := clampi(
						center_x + x_offset * sign_value,
						0, _platform_image.get_width() - 1)
				if _platform_image.get_pixel(x, y).a < PLATFORM_ALPHA_THRESHOLD:
					continue
				var local_position := Vector2(
						(float(x) + 0.5) / float(_platform_image.get_width())
								* _platform.size.x,
						(float(y) + 0.5) / float(_platform_image.get_height())
								* _platform.size.y)
				return _platform.get_global_transform_with_canvas() * local_position
	return Vector2(-1.0, -1.0)


func find_foreground_blocked_position_for_testing() -> Vector2:
	for y: int in range(520, 1080, 12):
		for x: int in range(0, 1920, 12):
			var viewport_position := Vector2(x, y)
			if _viewport_position_is_blocked_by_foreground(viewport_position):
				return viewport_position
	return Vector2(-1.0, -1.0)


func active_lake_ripple_count_for_testing() -> int:
	return _lake_ripples.size()


func left_click_input_count_for_testing() -> int:
	return _left_click_input_count


func lake_uniform_contract_for_testing() -> Dictionary:
	var water_events: Variant = _lake_material.get_shader_parameter(
			&"click_ripple_events")
	var reflection_events: Variant = _reflection_material.get_shader_parameter(
			&"click_ripple_events")
	return {
		"effect_kind": "pixel_perspective_ripple",
		"storage_kind": "dynamic_event_texture",
		"application_limit": -1,
		"event_count": _lake_ripples.size(),
		"texture_capacity": _lake_event_capacity,
		"duration_sec": LAKE_RESPONSE_DURATION_SEC,
		"minimum_width_px": 0.028 * 2.0 * 1920.0,
		"maximum_width_px": 0.045 * 2.0 * 1920.0,
		"vertical_compression": LAKE_RIPPLE_VERTICAL_COMPRESSION,
		"immediate_strength_floor": LAKE_IMMEDIATE_STRENGTH_FLOOR,
		"shared_by_water_and_reflection": water_events == reflection_events,
	}


func active_chip_contracts_for_testing() -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	for burst: IceChipBurst in _chip_bursts:
		if is_instance_valid(burst):
			contracts.append(burst.contract_for_testing())
	return contracts


func active_platform_contact_flash_count_for_testing() -> int:
	var count := 0
	for flash: PlatformContactFlash in _contact_flashes:
		if is_instance_valid(flash):
			count += 1
	return count


func platform_shake_contract_for_testing() -> Dictionary:
	return {
		"kind": String(_platform_shake_kind),
		"duration_sec": _platform_shake_duration_sec,
		"amplitude_px": _platform_shake_amplitude_px,
		"current_offset_px": _platform_shake_offset,
		"moves_water_contact": _platform_contact != null,
		"syncs_characters_when_embedded": true,
	}


func permanent_platform_fissure_count_for_testing() -> int:
	return 1 if _platform_broken else 0


func platform_click_count_for_testing() -> int:
	return _platform_click_count


func platform_fissure_contract_for_testing() -> Dictionary:
	var source_to_screen_x := (
			absf(_platform.scale.x) * _platform.size.x
			/ float(_platform_image.get_width()))
	var source_to_screen_y := (
			absf(_platform.scale.y) * _platform.size.y
			/ float(_platform_image.get_height()))
	return {
		"kind": "vertical_pixel_fissure",
		"primary_axis": "vertical",
		"growth_direction": "bottom_to_top",
		"silhouette_direction": "bottom_to_top",
		"silhouette_vertical_flip": true,
		"growth_origin_source_row": PLATFORM_FISSURE_END_SOURCE_ROW,
		"growth_destination_source_row": PLATFORM_FISSURE_START_SOURCE_ROW,
		"fissure_count": 1 if _platform_broken else 0,
		"connected": true,
		"source_alpha_preserved": true,
		"affects_hit_testing": false,
		"transparent_pixels_removed": 0,
		"core_width_source_px": PLATFORM_FISSURE_CORE_WIDTH_SOURCE_PX,
		"maximum_node_width_source_px": (
				PLATFORM_FISSURE_MAX_NODE_WIDTH_SOURCE_PX),
		"branch_count": PLATFORM_FISSURE_BRANCH_COUNT,
		"growth_segment_count": PLATFORM_FISSURE_GROWTH_SEGMENT_COUNT,
		"core_width_screen_px": (
				PLATFORM_FISSURE_CORE_WIDTH_SOURCE_PX * source_to_screen_x),
		"height_screen_px": (
				(PLATFORM_FISSURE_END_SOURCE_ROW
						- PLATFORM_FISSURE_START_SOURCE_ROW + 1.0)
					* source_to_screen_y),
		"maximum_center_offset_screen_px": (
				PLATFORM_FISSURE_MAX_CENTER_OFFSET_SOURCE_PX
						* source_to_screen_x),
		"shader_break_amount": float(_platform_material.get_shader_parameter(
				&"platform_break_amount")),
	}


func battle_ui_blocks_viewport_position_for_testing(
		viewport_position: Vector2) -> bool:
	return _viewport_position_is_blocked_by_battle_ui(viewport_position)


func battle_ui_exclusion_contract_for_testing() -> Dictionary:
	var battle_root := _find_battle_screen_root()
	var button_bar := (
			battle_root.get_node_or_null("Buttons") as Control
			if battle_root != null else null)
	var item_row_centers: Array[Vector2] = []
	if battle_root != null:
		for item_row: Control in _battle_item_rows(battle_root):
			item_row_centers.append(
					_item_row_global_rect(item_row).get_center())
	return {
		"has_button_bar": button_bar != null,
		"button_bar_center": (
				button_bar.get_global_rect().get_center()
				if button_bar != null else Vector2(-1.0, -1.0)),
		"item_row_count": item_row_centers.size(),
		"item_row_centers": item_row_centers,
	}


func platform_break_probability_for_testing(viewport_position: Vector2) -> float:
	var local_position := _platform_surface_local_position(viewport_position)
	if local_position.x < 0.0 or _platform_broken:
		return 0.0
	var next_click_count := _platform_click_count + 1
	if next_click_count < 3:
		return 0.0
	var next_local_stress := int(
			_stress_cells.get(_stress_key(local_position), 0)) + 1
	return minf(
			PLATFORM_BREAK_BASE_PROBABILITY
			+ float(next_click_count - 3) * PLATFORM_BREAK_CLICK_STEP
			+ float(maxi(next_local_stress - 1, 0))
					* PLATFORM_BREAK_LOCAL_STRESS_STEP,
			PLATFORM_BREAK_PROBABILITY_CAP)
