class_name MainMenuWorld
extends Control

## 晴风驿站主界面世界：复用远征地表与英雄 idle 资源，但不创建任何远征玩法状态。

signal movement_finished(cell: Vector2i, completed: bool)

const QingfengLayout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const GridPathfinderScript := preload("res://src/expedition/grid_pathfinder.gd")
const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProfileStore := preload("res://src/core/player_profile.gd")
const VISUAL_MAP_SCENE := preload("res://src/expedition/maps/qingfeng_ricefield_visual_map.tscn")
const GRASS_TILE_TEXTURE := preload("res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png")
const GROUND_CELL_SHADER := preload("res://assets/shaders/canvas_ui_expedition_ground_cell.gdshader")
const ATMOSPHERE_SHADER := preload("res://assets/shaders/canvas_ui_qingfeng_atmosphere.gdshader")

const MAP_CELL: float = 120.0
const MAP_RENDER_SCALE: float = 1.2
const RENDERED_CELL: float = MAP_CELL * MAP_RENDER_SCALE
const VISIBLE_COLS: int = 13
const VISIBLE_ROWS: int = 7
const VIEW_SIZE := Vector2(VISIBLE_COLS * RENDERED_CELL, VISIBLE_ROWS * RENDERED_CELL)
const MAP_WORLD_SIZE := Vector2(QingfengLayout.WIDTH * MAP_CELL, QingfengLayout.HEIGHT * MAP_CELL)
const HOME_CELL := QingfengLayout.START
const MAP_BOUNDS := Rect2i(Vector2i.ZERO, Vector2i(QingfengLayout.WIDTH, QingfengLayout.HEIGHT))
const WALK_STEP_DURATION: float = 0.22
const MAX_BUFFERED_KEY_STEPS: int = 2

const TOKEN_SIZE := Vector2(208.0, 208.0)
const TOKEN_FOOT_ANCHOR := Vector2(104.0, 156.0)
const TOKEN_CELL_FOOT_POINT := Vector2(60.0, 90.0)
const TOKEN_OFFSET := TOKEN_CELL_FOOT_POINT - TOKEN_FOOT_ANCHOR
const TOKEN_CONTENT_SCALE: float = 1.125
const H01_SOURCE_FOOT_MIDPOINT := Vector2(128.0, 182.0)
const TOKEN_IDLE_BASE_FPS: float = 8.0
const TOKEN_IDLE_REF_FRAMES: float = 6.0

const DESTINATION_CELLS: Dictionary = {
	"match": Vector2i(12, 14),
	"story": Vector2i(16, 13),
	"expedition": Vector2i(20, 14),
}
const DESTINATION_COLORS: Dictionary = {
	"match": Color("d96255"),
	"story": Color("a993df"),
	"expedition": Color("e3b94e"),
}

var map_view: Control
var map_world: Control
var visual_map: Node2D
var visual_ground: TileMapLayer
var ground_art: Control
var marker_art: Control
var atmosphere_layer: ColorRect
var atmosphere_material: ShaderMaterial
var player_shadow: Control
var player_token: TextureRect

var _hero_frames: SpriteFrames
var _hero_textures: Array[Texture2D] = []
var _anim_time: float = 0.0
var _focused_destination: String = ""
var _selected_destination: String = ""
var _transition_active: bool = false
var _move_tween: Tween
var _shadow_lift: float = 0.0
var _move_direction: Vector2 = Vector2.ZERO
var _current_token_origin: Vector2 = Vector2.ZERO
var _current_logical_origin: Vector2 = Vector2.ZERO
var _current_cell: Vector2i = HOME_CELL
var _movement_generation: int = 0
var _keyboard_step_queue: Array[Vector2i] = []
var _keyboard_runner_active: bool = false


func _ready() -> void:
	_build_world()
	resized.connect(_layout_view)
	_layout_view()
	_load_profile_hero()
	_set_token_origin(_token_origin_for_cell(HOME_CELL), 0.0, Vector2.ZERO)
	_current_logical_origin = _token_origin_for_cell(HOME_CELL)
	_update_camera_for_token_origin(_current_logical_origin)
	set_process(true)


func _build_world() -> void:
	var fallback := ColorRect.new()
	fallback.name = "FieldBackdrop"
	fallback.color = Color("17372d")
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fallback)

	map_view = Control.new()
	map_view.name = "MapView"
	map_view.size = VIEW_SIZE
	map_view.clip_contents = true
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	map_view.gui_input.connect(_on_map_view_gui_input)
	add_child(map_view)

	map_world = Control.new()
	map_world.name = "MapWorld"
	map_world.size = MAP_WORLD_SIZE
	map_world.scale = Vector2.ONE * MAP_RENDER_SCALE
	map_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.add_child(map_world)

	visual_map = VISUAL_MAP_SCENE.instantiate() as Node2D
	visual_map.name = "QingfengVisualMap"
	# 场景方案未定稿前只保留统一草格；远征地图的田埂、作物和容器全部隐藏。
	visual_map.visible = false
	map_world.add_child(visual_map)
	visual_ground = visual_map.get_node("Ground") as TileMapLayer
	visual_ground.visible = false

	ground_art = Control.new()
	ground_art.name = "GroundArt"
	ground_art.size = MAP_WORLD_SIZE
	ground_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND_CELL_SHADER
	ground_material.set_shader_parameter("cell_px", MAP_CELL)
	ground_material.set_shader_parameter("cell_inset_px", 1.0)
	ground_material.set_shader_parameter("corner_radius_px", 16.0)
	ground_material.set_shader_parameter("pixel_step_px", 4.0)
	ground_material.set_shader_parameter("border_px", 2.0)
	ground_material.set_shader_parameter("gap_color", Color("203a33"))
	ground_material.set_shader_parameter("border_color", Color("3b5233"))
	ground_art.material = ground_material
	ground_art.draw.connect(_draw_ground)
	map_world.add_child(ground_art)
	map_world.move_child(ground_art, 0)

	_build_atmosphere()

	marker_art = Control.new()
	marker_art.name = "DestinationMarkers"
	marker_art.size = MAP_WORLD_SIZE
	marker_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_art.draw.connect(_draw_destinations)
	map_world.add_child(marker_art)

	player_shadow = Control.new()
	player_shadow.name = "PlayerShadow"
	player_shadow.size = Vector2.ONE * MAP_CELL
	player_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_shadow.draw.connect(_draw_player_shadow)
	map_world.add_child(player_shadow)

	player_token = TextureRect.new()
	player_token.name = "PlayerToken"
	player_token.size = TOKEN_SIZE
	player_token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_token.pivot_offset = TOKEN_FOOT_ANCHOR
	player_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(player_token)


func _build_atmosphere() -> void:
	var visibility_image := Image.create(
			QingfengLayout.WIDTH, QingfengLayout.HEIGHT, false, Image.FORMAT_RGBA8)
	visibility_image.fill(Color(0.0, 1.0, 0.0, 1.0))
	var visibility_texture := ImageTexture.create_from_image(visibility_image)
	atmosphere_layer = ColorRect.new()
	atmosphere_layer.name = "Atmosphere"
	atmosphere_layer.size = VIEW_SIZE / MAP_RENDER_SCALE
	atmosphere_layer.color = Color.WHITE
	atmosphere_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere_material = ShaderMaterial.new()
	atmosphere_material.shader = ATMOSPHERE_SHADER
	atmosphere_material.set_shader_parameter("map_data", visibility_texture)
	atmosphere_material.set_shader_parameter("grid_size", Vector2(
			QingfengLayout.WIDTH, QingfengLayout.HEIGHT))
	atmosphere_material.set_shader_parameter("view_size_px", VIEW_SIZE / MAP_RENDER_SCALE)
	atmosphere_material.set_shader_parameter("cell_px", MAP_CELL)
	atmosphere_layer.material = atmosphere_material
	map_world.add_child(atmosphere_layer)


func _layout_view() -> void:
	if map_view == null:
		return
	map_view.position = ((size - VIEW_SIZE) * 0.5).round()
	_update_camera_for_token_origin(_token_origin_for_cell(_current_cell))


func _update_camera_for_token_origin(token_origin: Vector2) -> void:
	if map_world == null:
		return
	var cell_center: Vector2 = token_origin - TOKEN_OFFSET + Vector2.ONE * MAP_CELL * 0.5
	var desired: Vector2 = VIEW_SIZE * 0.5 - cell_center * MAP_RENDER_SCALE
	var rendered_map_size: Vector2 = MAP_WORLD_SIZE * MAP_RENDER_SCALE
	map_world.position = Vector2(
			clampf(desired.x, VIEW_SIZE.x - rendered_map_size.x, 0.0),
			clampf(desired.y, VIEW_SIZE.y - rendered_map_size.y, 0.0)
	).round()
	var camera_world_origin := -map_world.position / MAP_RENDER_SCALE
	atmosphere_layer.position = camera_world_origin
	atmosphere_material.set_shader_parameter("camera_world_origin_px", camera_world_origin)


func _draw_ground() -> void:
	ground_art.draw_rect(Rect2(Vector2.ZERO, MAP_WORLD_SIZE), Color("203a33"))
	for y: int in QingfengLayout.HEIGHT:
		for x: int in QingfengLayout.WIDTH:
			var cell := Vector2i(x, y)
			ground_art.draw_texture_rect(GRASS_TILE_TEXTURE, Rect2(Vector2(cell) * MAP_CELL,
					Vector2.ONE * MAP_CELL), false, Color.WHITE)


func _draw_destinations() -> void:
	for destination_id: String in DESTINATION_CELLS:
		var cell: Vector2i = DESTINATION_CELLS[destination_id]
		var color: Color = DESTINATION_COLORS[destination_id]
		var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * MAP_CELL
		var is_active: bool = destination_id == _focused_destination \
				or destination_id == _selected_destination
		var pulse: float = 0.5 + 0.5 * sin(_anim_time * 3.0)
		var alpha: float = 0.52 + pulse * 0.26 if is_active else 0.22
		var radius: float = 43.0 if is_active else 36.0
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
		])
		marker_art.draw_colored_polygon(diamond, Color(color, alpha * 0.34))
		marker_art.draw_polyline(PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
		]), Color(color, alpha), 5.0, false)
		var core_size: float = 14.0 if is_active else 10.0
		marker_art.draw_rect(Rect2(center - Vector2.ONE * core_size * 0.5,
				Vector2.ONE * core_size), Color(color, 0.82))


func _draw_player_shadow() -> void:
	var width: float = round(lerpf(62.0, 42.0, _shadow_lift) * 0.5) * 2.0
	var height: float = round(lerpf(12.0, 8.0, _shadow_lift))
	var opacity: float = lerpf(0.46, 0.24, _shadow_lift)
	var center := TOKEN_CELL_FOOT_POINT + Vector2(_move_direction.x * 2.0 * _shadow_lift, 2.0)
	player_shadow.draw_set_transform(center, 0.0, Vector2(width / height, 1.0))
	player_shadow.draw_circle(Vector2.ZERO, height * 0.5,
			Color(0.025, 0.070, 0.050, opacity), true, -1.0, false)
	player_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _load_profile_hero() -> void:
	var hero_id: String = ProfileStore.get_avatar_hero()
	var hero: HeroData = null
	for candidate: HeroData in HeroDataScript.create_launch_pool():
		if candidate.hero_id == hero_id:
			hero = candidate
			break
	if hero == null:
		hero = load("res://assets/data/heroes/h01.tres") as HeroData
	if hero == null:
		return
	if ResourceLoader.exists(hero.sprite_frames_path):
		_hero_frames = load(hero.sprite_frames_path) as SpriteFrames
	_build_hero_textures()
	_update_hero_frame()
	if player_token.texture == null and ResourceLoader.exists(hero.portrait_path):
		player_token.texture = load(hero.portrait_path) as Texture2D


func _build_hero_textures() -> void:
	_hero_textures.clear()
	if _hero_frames == null or not _hero_frames.has_animation(&"idle"):
		return
	var frame_count: int = _hero_frames.get_frame_count(&"idle")
	var target_size := Vector2i(int(TOKEN_SIZE.x), int(TOKEN_SIZE.y))
	var target_origin := Vector2i(
			Vector2(TOKEN_FOOT_ANCHOR - H01_SOURCE_FOOT_MIDPOINT * TOKEN_CONTENT_SCALE).round())
	for frame_index: int in frame_count:
		var source_texture: Texture2D = _hero_frames.get_frame_texture(&"idle", frame_index)
		if source_texture == null:
			continue
		var source_image: Image = source_texture.get_image()
		if source_image == null:
			continue
		source_image.convert(Image.FORMAT_RGBA8)
		var scaled_size := Vector2i(Vector2(source_image.get_size()) * TOKEN_CONTENT_SCALE)
		source_image.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
		var centered_frame := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
		centered_frame.blit_rect(source_image, Rect2i(Vector2i.ZERO, scaled_size), target_origin)
		_hero_textures.append(ImageTexture.create_from_image(centered_frame))


func _update_hero_frame() -> void:
	if player_token == null or _hero_textures.is_empty():
		return
	var fps: float = TOKEN_IDLE_BASE_FPS * float(_hero_textures.size()) / TOKEN_IDLE_REF_FRAMES
	var frame_index: int = int(floor(_anim_time * fps)) % _hero_textures.size()
	player_token.texture = _hero_textures[frame_index]


func focus_destination(destination_id: String) -> void:
	if not destination_id.is_empty() and not DESTINATION_CELLS.has(destination_id):
		return
	_focused_destination = destination_id
	if not _transition_active and not destination_id.is_empty():
		var target_cell: Vector2i = DESTINATION_CELLS[destination_id]
		var horizontal: float = signf(float(target_cell.x - _current_cell.x))
		if not is_zero_approx(horizontal):
			player_token.scale.x = absf(player_token.scale.x) * horizontal
	marker_art.queue_redraw()


func play_confirmation(destination_id: String) -> void:
	if _transition_active or not DESTINATION_CELLS.has(destination_id):
		return
	_transition_active = true
	_selected_destination = destination_id
	marker_art.queue_redraw()
	var destination_cell: Vector2i = DESTINATION_CELLS[destination_id]
	_cancel_keyboard_steps()
	_movement_generation += 1
	var generation: int = _movement_generation
	await _walk_path_to(destination_cell, generation)
	if not is_instance_valid(self):
		return
	_transition_active = false


func reset_home() -> void:
	_selected_destination = ""
	marker_art.queue_redraw()
	request_move_to_cell(HOME_CELL)


func request_move_to_cell(destination_cell: Vector2i) -> bool:
	if _transition_active or not MAP_BOUNDS.has_point(destination_cell):
		return false
	_cancel_keyboard_steps()
	_movement_generation += 1
	_walk_path_to(destination_cell, _movement_generation)
	return true


func request_step(direction: Vector2i) -> bool:
	if _transition_active or absi(direction.x) + absi(direction.y) != 1:
		return false
	if not _keyboard_runner_active:
		_movement_generation += 1
		_keyboard_runner_active = true
		_keyboard_step_queue.append(direction)
		_run_keyboard_steps(_movement_generation)
	elif _keyboard_step_queue.size() < MAX_BUFFERED_KEY_STEPS:
		_keyboard_step_queue.append(direction)
	return true


func _run_keyboard_steps(generation: int) -> void:
	while not _keyboard_step_queue.is_empty():
		if generation != _movement_generation:
			return
		var direction: Vector2i = _keyboard_step_queue.pop_front()
		var next_cell: Vector2i = _current_cell + direction
		if not MAP_BOUNDS.has_point(next_cell):
			continue
		await _walk_one_cell(next_cell)
		if not is_instance_valid(self) or generation != _movement_generation:
			return
	_keyboard_runner_active = false
	movement_finished.emit(_current_cell, true)


func _cancel_keyboard_steps() -> void:
	_keyboard_step_queue.clear()
	_keyboard_runner_active = false


func _walk_path_to(destination_cell: Vector2i, generation: int) -> bool:
	var path: Array[Vector2i] = GridPathfinderScript.find_path(
			_current_cell, destination_cell, MAP_BOUNDS,
			func(_cell: Vector2i) -> bool: return true)
	if destination_cell != _current_cell and path.is_empty():
		movement_finished.emit(_current_cell, false)
		return false
	for next_cell: Vector2i in path:
		if generation != _movement_generation:
			return false
		await _walk_one_cell(next_cell)
		if not is_instance_valid(self) or generation != _movement_generation:
			return false
	movement_finished.emit(_current_cell, true)
	return true


func _walk_one_cell(next_cell: Vector2i) -> void:
	var step: Vector2i = next_cell - _current_cell
	if absi(step.x) + absi(step.y) != 1:
		return
	var from_origin: Vector2 = _current_logical_origin
	var to_origin: Vector2 = _token_origin_for_cell(next_cell)
	_move_direction = Vector2(step)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_method(
			_set_walk_progress.bind(from_origin, to_origin, _move_direction),
			0.0, 1.0, WALK_STEP_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _move_tween.finished
	if not is_instance_valid(self):
		return
	_current_cell = next_cell
	_current_logical_origin = to_origin
	_set_token_origin(to_origin, 0.0, _move_direction)
	_update_camera_for_token_origin(to_origin)


func _on_map_view_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	var destination_cell: Vector2i = _cell_from_view_position(mouse_button.position)
	if request_move_to_cell(destination_cell):
		map_view.accept_event()


func _cell_from_view_position(view_position: Vector2) -> Vector2i:
	if map_world == null:
		return Vector2i(-1, -1)
	var world_position: Vector2 = (view_position - map_world.position) / MAP_RENDER_SCALE
	var cell := Vector2i(floori(world_position.x / MAP_CELL), floori(world_position.y / MAP_CELL))
	return cell if MAP_BOUNDS.has_point(cell) else Vector2i(-1, -1)


func _view_position_for_cell(cell: Vector2i) -> Vector2:
	return map_world.position + (Vector2(cell) + Vector2.ONE * 0.5) * RENDERED_CELL


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	var direction := Vector2i.ZERO
	match key_event.keycode:
		KEY_W:
			direction = Vector2i.UP
		KEY_S:
			direction = Vector2i.DOWN
		KEY_A:
			direction = Vector2i.LEFT
		KEY_D:
			direction = Vector2i.RIGHT
		_:
			return
	if request_step(direction):
		get_viewport().set_input_as_handled()


func flash_destination(destination_id: String) -> void:
	if not DESTINATION_CELLS.has(destination_id):
		return
	_selected_destination = destination_id
	marker_art.queue_redraw()
	var tween: Tween = create_tween()
	tween.tween_property(marker_art, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.10)
	tween.tween_property(marker_art, "modulate", Color.WHITE, 0.22)


func refresh_colors() -> void:
	ground_art.queue_redraw()
	marker_art.queue_redraw()


func get_visual_contract() -> Dictionary:
	return {
		"presentation_only": true,
		"uniform_grass_only": true,
		"visible_columns": VISIBLE_COLS,
		"visible_rows": VISIBLE_ROWS,
		"view_size": VIEW_SIZE,
		"rendered_cell": RENDERED_CELL,
		"destination_count": DESTINATION_CELLS.size(),
		"ground_cell_count": QingfengLayout.WIDTH * QingfengLayout.HEIGHT,
		"hero_frame_count": _hero_textures.size(),
		"hero_foot_anchor": TOKEN_FOOT_ANCHOR,
		"current_cell": _current_cell,
		"click_to_move": map_view != null and map_view.gui_input.is_connected(
				_on_map_view_gui_input),
		"wasd_to_move": true,
		"keyboard_buffered_steps": MAX_BUFFERED_KEY_STEPS,
	}


func _set_walk_progress(progress: float, from_origin: Vector2, to_origin: Vector2,
		direction: Vector2) -> void:
	var arc: float = sin(progress * PI)
	var logical_origin: Vector2 = from_origin.lerp(to_origin, progress)
	var hop := Vector2(direction.x * round(arc) * 5.0, -round(arc * 2.0) * 5.0)
	_current_logical_origin = logical_origin
	_set_token_origin(logical_origin + hop, arc, direction)
	_update_camera_for_token_origin(logical_origin)
	var facing: float = signf(direction.x)
	if not is_zero_approx(facing):
		player_token.scale = Vector2(facing, 1.0 + arc * 0.04)


func _set_token_origin(origin: Vector2, lift: float, direction: Vector2) -> void:
	_current_token_origin = origin
	_shadow_lift = clampf(lift, 0.0, 1.0)
	_move_direction = direction
	player_token.position = origin
	player_shadow.position = origin - TOKEN_OFFSET
	player_shadow.queue_redraw()


func _token_origin_for_cell(cell: Vector2i) -> Vector2:
	return Vector2(cell) * MAP_CELL + TOKEN_OFFSET


func _process(delta: float) -> void:
	_anim_time += delta
	_update_hero_frame()
	if atmosphere_material != null:
		atmosphere_material.set_shader_parameter("anim_time", _anim_time)
	if not _focused_destination.is_empty() or not _selected_destination.is_empty():
		marker_art.queue_redraw()
