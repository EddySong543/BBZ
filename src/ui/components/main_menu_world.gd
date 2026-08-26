class_name MainMenuWorld
extends Control

## 晴风驿站主界面世界：复用远征地表与英雄 idle 资源，但不创建任何远征玩法状态。

signal movement_finished(cell: Vector2i, completed: bool)

const QingfengLayout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const GridMovementControllerScript := preload("res://src/expedition/grid_movement_controller.gd")
const GridPathfinderScript := preload("res://src/expedition/grid_pathfinder.gd")
const GridRoutePreviewScript := preload("res://src/expedition/grid_route_preview.gd")
const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ProfileStore := preload("res://src/core/player_profile.gd")
const VISUAL_MAP_SCENE := preload("res://src/expedition/maps/qingfeng_ricefield_visual_map.tscn")
const GRASS_TILE_TEXTURE := preload("res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png")
const GROUND_CELL_SHADER := preload("res://assets/shaders/canvas_ui_expedition_ground_cell.gdshader")
const GRID_TARGET_OUTLINE_SHADER := preload(
		"res://assets/shaders/canvas_ui_grid_target_outline.gdshader")
const ATMOSPHERE_SHADER := preload("res://assets/shaders/canvas_ui_qingfeng_atmosphere.gdshader")
const PORTAL_STONE_SHADER := preload("res://assets/shaders/canvas_ui_portal_stone_energy.gdshader")
const PortalPixelBeamScript := preload("res://src/ui/components/portal_pixel_beam.gd")
const PORTAL_STONE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/main_menu/stone1.png"),
	preload("res://assets/ui/main_menu/stone2.png"),
	preload("res://assets/ui/main_menu/stone3.png"),
	preload("res://assets/ui/main_menu/stone4.png"),
]

const MAP_CELL: float = 120.0
const VISIBLE_COLS: int = 19
const VISIBLE_ROWS: int = 11
const VIEW_SIZE := Vector2(1920.0, 1080.0)
const MAP_RENDER_SCALE := Vector2(16.0 / 19.0, 9.0 / 11.0)
const RENDERED_CELL_SIZE := VIEW_SIZE / Vector2(VISIBLE_COLS, VISIBLE_ROWS)
const MAP_WORLD_SIZE := Vector2(QingfengLayout.WIDTH * MAP_CELL, QingfengLayout.HEIGHT * MAP_CELL)
const MAP_BOUNDS := Rect2i(Vector2i.ZERO, Vector2i(QingfengLayout.WIDTH, QingfengLayout.HEIGHT))
const HUB_CENTER_CELL := Vector2i(16, 9)
const CENTER_ENTRY_CELLS: Array[Vector2i] = [
	Vector2i(15, 8), Vector2i(16, 8), Vector2i(17, 8),
	Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9),
	Vector2i(15, 10), Vector2i(16, 10), Vector2i(17, 10),
]
const PORTAL_STONE_CELLS: Array[Vector2i] = [
	Vector2i(15, 8), Vector2i(17, 8),
	Vector2i(15, 10), Vector2i(17, 10),
]
const PORTAL_STONE_SIZE := Vector2(128.0, 128.0)
const PORTAL_STONE_FOOT_ANCHORS: Array[Vector2] = [
	Vector2(63.0, 119.0), Vector2(65.5, 116.0),
	Vector2(64.0, 114.0), Vector2(64.0, 104.0),
]
const PORTAL_STONE_SCALE: float = 0.72
const PORTAL_FLOAT_AMPLITUDE: float = 3.0
const PORTAL_FLOAT_PERIOD: float = 3.8
const PORTAL_ACTIVATION_DURATION: float = 2.0
const PORTAL_SEARCH_STEP_DELAY: float = 0.34
const PORTAL_IGNITE_DURATION: float = 0.38
const PORTAL_BLOCK_LEAN_DISTANCE: float = 8.0
const PORTAL_BLOCK_RECOIL_DISTANCE: float = 5.0
const PORTAL_BEAM_DURATION: float = 1.80
const PORTAL_BEAM_PEAK_HOLD_RATIO: float = 0.10
const PORTAL_ENERGY_GOLD := Color("FFC44F")
const PORTAL_ENERGY_BLUE := Color("48A8FF")
const TOKEN_SIZE := Vector2(208.0, 208.0)
const TOKEN_FOOT_ANCHOR := Vector2(104.0, 156.0)
const TOKEN_CELL_FOOT_POINT := Vector2(60.0, 90.0)
const TOKEN_OFFSET := TOKEN_CELL_FOOT_POINT - TOKEN_FOOT_ANCHOR
const TOKEN_CONTENT_SCALE: float = 1.125
const H01_SOURCE_FOOT_MIDPOINT := Vector2(128.0, 182.0)
const TOKEN_IDLE_BASE_FPS: float = 8.0
const TOKEN_IDLE_REF_FRAMES: float = 6.0
const TOKEN_ASPECT_COMPENSATION := Vector2(
		MAP_RENDER_SCALE.y / MAP_RENDER_SCALE.x, 1.0)

# 匹配与远征已经改为底部直接入口；展示地图不再绘制或保留对应目的地格。
const DESTINATION_CELLS: Dictionary = {}
const DESTINATION_COLORS: Dictionary = {}

var map_view: Control
var map_world: Control
var visual_map: Node2D
var visual_ground: TileMapLayer
var ground_art: Control
var marker_art: Control
var route_preview_art: Control
var route_target_outline: ColorRect
var route_target_material: ShaderMaterial
var atmosphere_layer: ColorRect
var atmosphere_material: ShaderMaterial
var player_shadow: Control
var player_token: TextureRect
var portal_stones: Array[TextureRect] = []
var portal_stone_shadows: Array[Control] = []
var portal_beam: PortalPixelBeam

var _hero_frames: SpriteFrames
var _hero_textures: Array[Texture2D] = []
var _portal_stone_home_positions: Array[Vector2] = []
var _portal_stone_materials: Array[ShaderMaterial] = []
var _portal_stone_lifts: Array[float] = []
var _portal_stone_impact_offsets: Array[Vector2] = []
var _portal_energy_levels: Array[float] = []
var _portal_energy_tweens: Array[Tween] = []
var _portal_sequence_tween: Tween
var _portal_energy_mix: float = 0.0
var _portal_energy_color: Color = Color.WHITE
var _portal_connection_complete: bool = false
var _portal_beam_tween: Tween
var _portal_beam_progress: float = 0.0
var _blocked_feedback_strength: float = 0.0
var _blocked_feedback_direction: Vector2 = Vector2.ZERO
var _blocked_stone_index: int = -1
var _blocked_feedback_tween: Tween
var _anim_time: float = 0.0
var _focused_destination: String = ""
var _selected_destination: String = ""
var _transition_active: bool = false
var _shadow_lift: float = 0.0
var _move_direction: Vector2 = Vector2.ZERO
var _current_token_origin: Vector2 = Vector2.ZERO
var _current_logical_origin: Vector2 = Vector2.ZERO
var _spawn_cell: Vector2i = HUB_CENTER_CELL
var _current_cell: Vector2i = HUB_CENTER_CELL
var _grid_movement: GridMovementController
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _hovered_path: Array[Vector2i] = []
var _pending_blocked_stone_index: int = -1


func _ready() -> void:
	_spawn_cell = HUB_CENTER_CELL
	_current_cell = _spawn_cell
	_build_world()
	resized.connect(_layout_view)
	_layout_view()
	_load_profile_hero()
	_grid_movement = GridMovementControllerScript.new()
	_grid_movement.configure(
			_spawn_cell, MAP_BOUNDS, MAP_CELL, TOKEN_OFFSET,
			_is_main_cell_walkable, _commit_main_step)
	_grid_movement.step_attempted.connect(_on_shared_step_attempted)
	_grid_movement.step_committed.connect(_on_shared_step_committed)
	_grid_movement.movement_finished.connect(_on_shared_movement_finished)
	_apply_shared_movement_visual()
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
	map_view.mouse_exited.connect(_clear_route_preview)
	add_child(map_view)

	map_world = Control.new()
	map_world.name = "MapWorld"
	map_world.size = MAP_WORLD_SIZE
	map_world.scale = MAP_RENDER_SCALE
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

	route_preview_art = Control.new()
	route_preview_art.name = "RoutePreview"
	route_preview_art.size = MAP_WORLD_SIZE
	route_preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_preview_art.z_index = 900
	route_preview_art.draw.connect(_draw_route_preview)
	map_world.add_child(route_preview_art)
	route_target_outline = ColorRect.new()
	route_target_outline.name = "RouteTargetOutline"
	route_target_outline.size = Vector2.ONE * MAP_CELL
	route_target_outline.color = Color.WHITE
	route_target_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_target_outline.z_index = 901
	route_target_outline.visible = false
	route_target_material = ShaderMaterial.new()
	route_target_material.shader = GRID_TARGET_OUTLINE_SHADER
	route_target_material.set_shader_parameter("cell_px", MAP_CELL)
	route_target_material.set_shader_parameter("cell_inset_px", 1.0)
	route_target_material.set_shader_parameter("corner_radius_px", 16.0)
	route_target_material.set_shader_parameter("pixel_step_px", 4.0)
	route_target_material.set_shader_parameter("outline_px", 4.0)
	route_target_material.set_shader_parameter("outline_alpha", 1.0)
	route_target_material.set_shader_parameter("fill_alpha", 0.10)
	route_target_outline.material = route_target_material
	map_world.add_child(route_target_outline)

	_build_portal_stones()

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

	_build_portal_beam()


func _build_portal_beam() -> void:
	portal_beam = PortalPixelBeamScript.new() as PortalPixelBeam
	portal_beam.name = "PortalBeamToScreenTop"
	var base_size: Vector2 = RENDERED_CELL_SIZE * 3.0
	var base_rect := Rect2(VIEW_SIZE * 0.5 - base_size * 0.5, base_size)
	portal_beam.position = Vector2.ZERO
	portal_beam.size = VIEW_SIZE
	portal_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portal_beam.z_index = 4096
	portal_beam.visible = false
	portal_beam.set_portal_base_rect(base_rect)
	portal_beam.set_beam_color(Color.WHITE)
	portal_beam.set_beam_progress(0.0)
	map_view.add_child(portal_beam)


func _build_portal_stones() -> void:
	portal_stones.clear()
	portal_stone_shadows.clear()
	_portal_stone_home_positions.clear()
	_portal_stone_materials.clear()
	_portal_stone_lifts.clear()
	_portal_stone_impact_offsets.clear()
	_portal_energy_levels.clear()
	for index: int in PORTAL_STONE_CELLS.size():
		var stone_cell: Vector2i = PORTAL_STONE_CELLS[index]
		var stone_shadow := Control.new()
		stone_shadow.name = "PortalStoneShadow%d" % (index + 1)
		stone_shadow.position = Vector2(stone_cell) * MAP_CELL
		stone_shadow.size = Vector2.ONE * MAP_CELL
		stone_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stone_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stone_shadow.z_index = roundi(stone_shadow.position.y + TOKEN_CELL_FOOT_POINT.y) - 1
		stone_shadow.draw.connect(_draw_portal_stone_shadow.bind(stone_shadow, index))
		map_world.add_child(stone_shadow)
		portal_stone_shadows.append(stone_shadow)
		_portal_stone_lifts.append(0.0)
		_portal_stone_impact_offsets.append(Vector2.ZERO)
		_portal_energy_levels.append(0.0)

		var stone := TextureRect.new()
		stone.name = "PortalStone%d" % (index + 1)
		stone.texture = PORTAL_STONE_TEXTURES[index]
		stone.size = PORTAL_STONE_SIZE
		stone.pivot_offset = PORTAL_STONE_FOOT_ANCHORS[index]
		stone.scale = TOKEN_ASPECT_COMPENSATION * PORTAL_STONE_SCALE
		stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var home_position: Vector2 = Vector2(stone_cell) * MAP_CELL \
				+ TOKEN_CELL_FOOT_POINT - PORTAL_STONE_FOOT_ANCHORS[index]
		stone.position = home_position
		stone.z_index = roundi(Vector2(stone_cell).y * MAP_CELL + TOKEN_CELL_FOOT_POINT.y)
		var stone_material := ShaderMaterial.new()
		stone_material.shader = PORTAL_STONE_SHADER
		stone_material.set_shader_parameter("energy_color", Color.WHITE)
		stone_material.set_shader_parameter("energy_mix", 0.0)
		stone_material.set_shader_parameter("energy_phase", float(index) * 1.73)
		stone_material.set_shader_parameter("activation_flash", 0.0)
		stone_material.set_shader_parameter("impact_pulse", 0.0)
		stone.material = stone_material
		map_world.add_child(stone)
		portal_stones.append(stone)
		_portal_stone_home_positions.append(home_position)
		_portal_stone_materials.append(stone_material)


func _draw_portal_stone_shadow(shadow: Control, index: int) -> void:
	if index < 0 or index >= _portal_stone_lifts.size():
		return
	var height_factor: float = clampf(
			-_portal_stone_lifts[index] / PORTAL_FLOAT_AMPLITUDE, -1.0, 1.0)
	var width: float = (40.0 - height_factor * 3.0) * TOKEN_ASPECT_COMPENSATION.x
	var height: float = 10.0
	var opacity: float = 0.28 - height_factor * 0.055
	var center: Vector2 = TOKEN_CELL_FOOT_POINT + Vector2(0.0, 3.0)
	shadow.draw_set_transform(center, 0.0, Vector2(width / height, 1.0))
	shadow.draw_circle(Vector2.ZERO, height * 0.5,
			Color(0.02, 0.055, 0.045, opacity), true, -1.0, false)
	shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## PVE：固定两秒内按左上、右上、左下、右下依次完成，最后一颗稳定即连接成功。
func play_portal_activation(color: Color,
		duration: float = PORTAL_ACTIVATION_DURATION) -> void:
	_prepare_portal_energy(color)
	var safe_duration: float = maxf(duration, PORTAL_IGNITE_DURATION + 0.20)
	var first_delay: float = 0.08
	var step_delay: float = (
			safe_duration - first_delay - PORTAL_IGNITE_DURATION - 0.08) / 3.0
	for index: int in portal_stones.size():
		_schedule_portal_ignite(index, first_delay + step_delay * float(index))
	_portal_sequence_tween = create_tween().bind_node(self)
	_portal_sequence_tween.tween_interval(safe_duration)
	await _portal_sequence_tween.finished
	if not is_instance_valid(self):
		return
	for index: int in _portal_energy_levels.size():
		_set_portal_stone_energy_level(1.0, index)
	_portal_connection_complete = true


## PVP 等待是未知时长：前三颗依次锁定，第四颗保留白色直到服务器确认成功。
func begin_portal_search(color: Color) -> void:
	_prepare_portal_energy(color)
	for index: int in mini(3, portal_stones.size()):
		_schedule_portal_ignite(index, 0.04 + PORTAL_SEARCH_STEP_DELAY * float(index))


## 快速匹配允许直接完成四颗；已有进度则由当前状态汇聚为同一拍能量闪光。
func complete_portal_connection(color: Color) -> void:
	_kill_portal_energy_tweens()
	_portal_energy_color = color
	_portal_connection_complete = true
	for index: int in _portal_stone_materials.size():
		_portal_stone_materials[index].set_shader_parameter("energy_color", color)
		_set_portal_stone_energy_level(1.0, index)
		_portal_stone_materials[index].set_shader_parameter("activation_flash", 1.0)
	var surge := create_tween().bind_node(self).set_parallel(true)
	for index: int in _portal_stone_materials.size():
		surge.tween_method(_set_portal_activation_flash.bind(index),
				1.0, 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_portal_energy_tweens.append(surge)


## 四石已连接后，中央3×3阵面升起ref44式紫边象牙亮核粗像素光柱。
func play_portal_beam(_color: Color, duration: float = PORTAL_BEAM_DURATION) -> void:
	if not _portal_connection_complete or portal_beam == null:
		return
	if _portal_beam_tween != null and _portal_beam_tween.is_valid():
		_portal_beam_tween.kill()
	var safe_duration: float = maxf(duration, 0.08)
	portal_beam.visible = true
	portal_beam.set_beam_color(PortalPixelBeam.REF44_BODY)
	_set_portal_beam_progress(0.0)
	_portal_beam_tween = create_tween().bind_node(self)
	# 九格阵面预热、象牙亮核先行、紫色连续轮廓追上、内部光痕上行、峰值停留。
	_portal_beam_tween.tween_method(
			_set_portal_beam_progress, 0.0, 0.22, safe_duration * 0.20
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_portal_beam_tween.tween_method(
			_set_portal_beam_progress, 0.22, 0.50, safe_duration * 0.18
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_portal_beam_tween.tween_method(
			_set_portal_beam_progress, 0.50, 0.72, safe_duration * 0.22
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_portal_beam_tween.tween_method(
			_set_portal_beam_progress, 0.72, 0.90, safe_duration * 0.18
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_portal_beam_tween.tween_method(
			_set_portal_beam_progress, 0.90, 1.0, safe_duration * 0.12
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_portal_beam_tween.tween_interval(safe_duration * PORTAL_BEAM_PEAK_HOLD_RATIO)
	await _portal_beam_tween.finished
	if is_instance_valid(self):
		_set_portal_beam_progress(1.0)


func _set_portal_beam_progress(value: float) -> void:
	_portal_beam_progress = clampf(value, 0.0, 1.0)
	if portal_beam != null:
		portal_beam.set_beam_progress(_portal_beam_progress)


func reset_portal_energy() -> void:
	_kill_portal_energy_tweens()
	if _portal_beam_tween != null and _portal_beam_tween.is_valid():
		_portal_beam_tween.kill()
	if portal_beam != null:
		portal_beam.visible = false
	_set_portal_beam_progress(0.0)
	_portal_connection_complete = false
	_portal_energy_color = Color.WHITE
	for index: int in _portal_stone_materials.size():
		_portal_stone_materials[index].set_shader_parameter("energy_color", Color.WHITE)
		var fade := create_tween().bind_node(self)
		fade.tween_method(_set_portal_stone_energy_level.bind(index),
				_portal_energy_levels[index], 0.0, 0.20
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_portal_energy_tweens.append(fade)


func _set_portal_energy_mix(value: float) -> void:
	for index: int in _portal_energy_levels.size():
		_set_portal_stone_energy_level(value, index)
	_portal_connection_complete = value >= 0.999


func _prepare_portal_energy(color: Color) -> void:
	_kill_portal_energy_tweens()
	_portal_energy_color = color
	_portal_connection_complete = false
	for index: int in _portal_stone_materials.size():
		_portal_stone_materials[index].set_shader_parameter("energy_color", color)
		_portal_stone_materials[index].set_shader_parameter("activation_flash", 0.0)
		_set_portal_stone_energy_level(0.0, index)


func _schedule_portal_ignite(index: int, delay: float) -> void:
	var ignite := create_tween().bind_node(self)
	ignite.tween_interval(maxf(delay, 0.0))
	ignite.tween_method(_set_portal_stone_energy_level.bind(index),
			0.0, 0.34, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ignite.tween_method(_set_portal_stone_energy_level.bind(index),
			0.34, 0.12, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ignite.tween_method(_set_portal_stone_energy_level.bind(index),
			0.12, 1.0, PORTAL_IGNITE_DURATION - 0.14
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_portal_energy_tweens.append(ignite)


func _set_portal_stone_energy_level(value: float, index: int) -> void:
	if index < 0 or index >= _portal_energy_levels.size():
		return
	var level: float = clampf(value, 0.0, 1.0)
	_portal_energy_levels[index] = level
	_portal_stone_materials[index].set_shader_parameter("energy_mix", level)
	_portal_stone_materials[index].set_shader_parameter(
			"activation_flash", sin(level * PI) * 0.72)
	var total: float = 0.0
	for energy_level: float in _portal_energy_levels:
		total += energy_level
	_portal_energy_mix = total / float(maxi(_portal_energy_levels.size(), 1))


func _set_portal_activation_flash(value: float, index: int) -> void:
	if index >= 0 and index < _portal_stone_materials.size():
		_portal_stone_materials[index].set_shader_parameter(
				"activation_flash", clampf(value, 0.0, 1.0))


func _kill_portal_energy_tweens() -> void:
	if _portal_sequence_tween != null and _portal_sequence_tween.is_valid():
		_portal_sequence_tween.kill()
	for energy_tween: Tween in _portal_energy_tweens:
		if energy_tween != null and energy_tween.is_valid():
			energy_tween.kill()
	_portal_energy_tweens.clear()


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
	# 主界面使用 1920×1080 设计坐标；19×11 格已经精确铺满，不再按临时
	# headless viewport 尺寸居中，否则会重新露出兜底外圈。
	map_view.position = Vector2.ZERO
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
	)
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
	width *= TOKEN_ASPECT_COMPENSATION.x
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
			_grid_movement.facing_sign = horizontal
			_grid_movement.turn_from_sign = horizontal
			_grid_movement.turn_target_sign = horizontal
			player_token.scale = _token_scale_for_render(_grid_movement.token_scale())
	marker_art.queue_redraw()


func play_confirmation(destination_id: String) -> void:
	if _transition_active or not DESTINATION_CELLS.has(destination_id):
		return
	_transition_active = true
	_selected_destination = destination_id
	marker_art.queue_redraw()
	var destination_cell: Vector2i = DESTINATION_CELLS[destination_id]
	if not _grid_movement.request_path(destination_cell):
		_transition_active = false
		return
	await movement_finished
	if not is_instance_valid(self):
		return
	_transition_active = false


func reset_home() -> void:
	_selected_destination = ""
	marker_art.queue_redraw()
	request_move_to_cell(_spawn_cell)


func request_move_to_cell(destination_cell: Vector2i) -> bool:
	if _transition_active or _grid_movement == null:
		return false
	_pending_blocked_stone_index = -1
	return _grid_movement.request_path(destination_cell)


func request_step(direction: Vector2i) -> bool:
	if _transition_active or _grid_movement == null:
		return false
	return _grid_movement.request_keyboard_step(direction) != "blocked"


func _is_main_cell_walkable(cell: Vector2i) -> bool:
	return MAP_BOUNDS.has_point(cell) and not PORTAL_STONE_CELLS.has(cell)


func _commit_main_step(direction: Vector2i) -> Dictionary:
	var next_cell: Vector2i = _grid_movement.current_cell + direction
	var moved: bool = _is_main_cell_walkable(next_cell)
	return {
		"moved": moved,
		"kind": "move" if moved else "blocked",
		"cell": next_cell,
	}


func _on_shared_step_attempted(from_cell: Vector2i, direction: Vector2i,
		result: Dictionary) -> void:
	if bool(result.get("moved", false)):
		return
	var blocked_cell: Vector2i = from_cell + direction
	var stone_index: int = PORTAL_STONE_CELLS.find(blocked_cell)
	if stone_index >= 0:
		_play_portal_blocked_feedback(Vector2(direction), stone_index)


func _play_portal_blocked_feedback(direction: Vector2, stone_index: int) -> void:
	if stone_index < 0 or stone_index >= portal_stones.size():
		return
	if _blocked_feedback_tween != null and _blocked_feedback_tween.is_valid():
		_blocked_feedback_tween.kill()
	if _blocked_stone_index >= 0 and _blocked_stone_index < _portal_stone_impact_offsets.size():
		_portal_stone_impact_offsets[_blocked_stone_index] = Vector2.ZERO
		_portal_stone_materials[_blocked_stone_index].set_shader_parameter(
				"impact_pulse", 0.0)
	_blocked_stone_index = stone_index
	_blocked_feedback_direction = direction.normalized()
	if _grid_movement != null and not is_zero_approx(_blocked_feedback_direction.x):
		var facing: float = signf(_blocked_feedback_direction.x)
		_grid_movement.facing_sign = facing
		_grid_movement.turn_from_sign = facing
		_grid_movement.turn_target_sign = facing
		_grid_movement.turn_active = false
	_set_portal_block_feedback(0.0, _blocked_feedback_direction, stone_index)
	_blocked_feedback_tween = create_tween().bind_node(self)
	_blocked_feedback_tween.tween_method(
			_set_portal_block_feedback.bind(_blocked_feedback_direction, stone_index),
			0.0, 1.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blocked_feedback_tween.tween_method(
			_set_portal_block_feedback.bind(_blocked_feedback_direction, stone_index),
			1.0, 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_portal_block_feedback(value: float, direction: Vector2,
		stone_index: int) -> void:
	_blocked_feedback_strength = clampf(value, 0.0, 1.0)
	_blocked_feedback_direction = direction
	if stone_index < 0 or stone_index >= _portal_stone_impact_offsets.size():
		return
	_portal_stone_impact_offsets[stone_index] = direction * roundf(
			_blocked_feedback_strength * PORTAL_BLOCK_RECOIL_DISTANCE)
	_portal_stone_materials[stone_index].set_shader_parameter(
			"impact_pulse", _blocked_feedback_strength)


func _on_shared_step_committed(_from_cell: Vector2i, to_cell: Vector2i,
		direction: Vector2i, _result: Dictionary) -> void:
	_current_cell = to_cell
	_move_direction = Vector2(direction)
	_refresh_route_preview()


func _on_shared_movement_finished(cell: Vector2i, completed: bool) -> void:
	_current_cell = cell
	if completed and _pending_blocked_stone_index >= 0:
		var stone_index: int = _pending_blocked_stone_index
		_pending_blocked_stone_index = -1
		var direction: Vector2i = PORTAL_STONE_CELLS[stone_index] - _current_cell
		if absi(direction.x) + absi(direction.y) == 1:
			_play_portal_blocked_feedback(Vector2(direction), stone_index)
	else:
		_pending_blocked_stone_index = -1
	movement_finished.emit(cell, completed)


func _on_map_view_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered_cell(_cell_from_view_position((event as InputEventMouseMotion).position))
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	var destination_cell: Vector2i = _cell_from_view_position(mouse_button.position)
	if PORTAL_STONE_CELLS.has(destination_cell):
		_request_move_to_portal_stone(PORTAL_STONE_CELLS.find(destination_cell))
		map_view.accept_event()
		return
	if request_move_to_cell(destination_cell):
		map_view.accept_event()


func _request_move_to_portal_stone(stone_index: int) -> bool:
	if stone_index < 0 or stone_index >= PORTAL_STONE_CELLS.size():
		return false
	var stone_cell: Vector2i = PORTAL_STONE_CELLS[stone_index]
	var direction: Vector2i = stone_cell - _current_cell
	if absi(direction.x) + absi(direction.y) == 1:
		_pending_blocked_stone_index = -1
		_play_portal_blocked_feedback(Vector2(direction), stone_index)
		return true
	var approach: Dictionary = _find_portal_approach(stone_cell)
	var destination := Vector2i(approach.get("destination", Vector2i(-1, -1)))
	if destination == Vector2i(-1, -1):
		return false
	_pending_blocked_stone_index = stone_index
	if not _grid_movement.request_path(destination):
		_pending_blocked_stone_index = -1
		return false
	return true


func _find_portal_approach(stone_cell: Vector2i) -> Dictionary:
	var best_path: Array[Vector2i] = []
	var best_destination := Vector2i(-1, -1)
	for direction: Vector2i in GridPathfinderScript.CARDINAL_DIRECTIONS:
		var candidate: Vector2i = stone_cell + direction
		if not _is_main_cell_walkable(candidate):
			continue
		var candidate_path: Array[Vector2i] = GridPathfinderScript.find_path(
				_current_cell, candidate, MAP_BOUNDS, _is_main_cell_walkable)
		if candidate != _current_cell and candidate_path.is_empty():
			continue
		if best_destination == Vector2i(-1, -1) \
				or candidate_path.size() < best_path.size():
			best_destination = candidate
			best_path = candidate_path
	return {"destination": best_destination, "path": best_path}


func _set_hovered_cell(cell: Vector2i) -> void:
	if cell == _hovered_cell:
		return
	_hovered_cell = cell
	_refresh_route_preview()


func _clear_route_preview() -> void:
	_hovered_cell = Vector2i(-1, -1)
	_hovered_path.clear()
	if route_target_outline != null:
		route_target_outline.visible = false
	if route_preview_art != null:
		route_preview_art.queue_redraw()


func _refresh_route_preview() -> void:
	_hovered_path.clear()
	if _hovered_cell == Vector2i(-1, -1) or _grid_movement == null:
		if route_target_outline != null:
			route_target_outline.visible = false
		if route_preview_art != null:
			route_preview_art.queue_redraw()
		return
	if route_target_outline != null:
		route_target_outline.position = Vector2(_hovered_cell) * MAP_CELL
		route_target_outline.visible = true
		route_target_material.set_shader_parameter("target_color",
				Color("F09A78") if not _is_main_cell_walkable(_hovered_cell)
				else Color("FFE0A0"))
	if PORTAL_STONE_CELLS.has(_hovered_cell):
		var approach: Dictionary = _find_portal_approach(_hovered_cell)
		_hovered_path.assign(approach.get("path", []))
		_hovered_path.append(_hovered_cell)
	elif _is_main_cell_walkable(_hovered_cell):
		_hovered_path = GridPathfinderScript.find_path(
				_current_cell, _hovered_cell, MAP_BOUNDS, _is_main_cell_walkable)
	if route_preview_art != null:
		route_preview_art.queue_redraw()


func _draw_route_preview() -> void:
	if _hovered_cell == Vector2i(-1, -1):
		return
	if _hovered_path.is_empty():
		return
	var route_cells: Array[Vector2i] = [_current_cell]
	route_cells.append_array(_hovered_path)
	GridRoutePreviewScript.draw_preview(
			route_preview_art, route_cells, MAP_CELL, _anim_time)


func _cell_from_view_position(view_position: Vector2) -> Vector2i:
	if map_world == null:
		return Vector2i(-1, -1)
	var world_position: Vector2 = (view_position - map_world.position) / MAP_RENDER_SCALE
	var cell := Vector2i(floori(world_position.x / MAP_CELL), floori(world_position.y / MAP_CELL))
	return cell if MAP_BOUNDS.has_point(cell) else Vector2i(-1, -1)


func _view_position_for_cell(cell: Vector2i) -> Vector2:
	return map_world.position + (Vector2(cell) + Vector2.ONE * 0.5) \
			* RENDERED_CELL_SIZE


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
		"rendered_cell_size": RENDERED_CELL_SIZE,
		"render_scale": MAP_RENDER_SCALE,
		"destination_count": DESTINATION_CELLS.size(),
		"ground_cell_count": QingfengLayout.WIDTH * QingfengLayout.HEIGHT,
		"hero_frame_count": _hero_textures.size(),
		"hero_foot_anchor": TOKEN_FOOT_ANCHOR,
		"spawn_cell": _spawn_cell,
		"hub_center_cell": HUB_CENTER_CELL,
		"center_entry_cells": CENTER_ENTRY_CELLS,
		"portal_stone_count": portal_stones.size(),
		"portal_stone_cells": PORTAL_STONE_CELLS,
		"portal_stone_texture_paths": PORTAL_STONE_TEXTURES.map(
				func(texture: Texture2D) -> String: return texture.resource_path),
		"portal_stone_foot_anchors": PORTAL_STONE_FOOT_ANCHORS,
		"portal_stone_scale": PORTAL_STONE_SCALE,
		"portal_stone_shadow_count": portal_stone_shadows.size(),
		"portal_cell_foot_point": TOKEN_CELL_FOOT_POINT,
		"portal_float_amplitude": PORTAL_FLOAT_AMPLITUDE,
		"portal_float_period": PORTAL_FLOAT_PERIOD,
		"portal_activation_duration": PORTAL_ACTIVATION_DURATION,
		"portal_blocked_cells": PORTAL_STONE_CELLS,
		"portal_energy_mix": _portal_energy_mix,
		"portal_energy_color": _portal_energy_color,
		"portal_energy_levels": _portal_energy_levels.duplicate(),
		"portal_connection_complete": _portal_connection_complete,
		"portal_beam_rect": Rect2(portal_beam.position, portal_beam.size) \
				if portal_beam != null else Rect2(),
		"portal_beam_base_rect": Rect2(
				VIEW_SIZE * 0.5 - RENDERED_CELL_SIZE * 1.5,
				RENDERED_CELL_SIZE * 3.0),
		"portal_beam_visible": portal_beam != null and portal_beam.visible,
		"portal_beam_progress": _portal_beam_progress,
		"portal_beam_contract": portal_beam.get_visual_contract() \
				if portal_beam != null else {},
		"portal_blocked_feedback_strength": _blocked_feedback_strength,
		"current_cell": _current_cell,
		"click_to_move": map_view != null and map_view.gui_input.is_connected(
				_on_map_view_gui_input),
		"wasd_to_move": false,
		"route_preview_connected": route_preview_art != null,
		"shared_movement_controller": _grid_movement != null,
		"movement_controller_script": _grid_movement.get_script().resource_path \
				if _grid_movement != null else "",
		"movement_damping": GridMovementControllerScript.CRITICAL_DAMPING,
	}


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
	_update_portal_stones()
	if _grid_movement != null:
		_grid_movement.process(delta)
		_apply_shared_movement_visual()
	_update_hero_frame()
	if atmosphere_material != null:
		atmosphere_material.set_shader_parameter("anim_time", _anim_time)
	if not _focused_destination.is_empty() or not _selected_destination.is_empty():
		marker_art.queue_redraw()
	if _hovered_cell != Vector2i(-1, -1) and route_preview_art != null:
		route_preview_art.queue_redraw()


func _update_portal_stones() -> void:
	for index: int in portal_stones.size():
		var phase: float = float(index) * TAU / float(portal_stones.size())
		var lift: float = sin(_anim_time * TAU / PORTAL_FLOAT_PERIOD + phase) \
				* PORTAL_FLOAT_AMPLITUDE
		_portal_stone_lifts[index] = lift
		portal_stones[index].position = _portal_stone_home_positions[index] \
				+ Vector2(0.0, lift) + _portal_stone_impact_offsets[index]
		_portal_stone_materials[index].set_shader_parameter("anim_time", _anim_time)
		portal_stone_shadows[index].queue_redraw()
	if portal_beam != null:
		portal_beam.set_anim_time(_anim_time)


func _apply_shared_movement_visual() -> void:
	if _grid_movement == null or player_token == null or player_shadow == null:
		return
	_current_cell = _grid_movement.current_cell
	_current_logical_origin = _grid_movement.visual_origin
	var rendered_origin: Vector2 = _grid_movement.quantized_visual_origin()
	var step_offset: Vector2 = _grid_movement.step_offset()
	var blocked_offset: Vector2 = _blocked_feedback_direction * roundf(
			_blocked_feedback_strength * PORTAL_BLOCK_LEAN_DISTANCE)
	_current_token_origin = rendered_origin + step_offset + blocked_offset
	_move_direction = _grid_movement.step_direction
	_shadow_lift = sin(_grid_movement.step_progress() * PI) \
			if _grid_movement.step_active else 0.0
	player_token.position = _current_token_origin
	player_token.rotation = _grid_movement.token_rotation() \
			+ _blocked_feedback_direction.x * _blocked_feedback_strength * 0.018
	player_token.scale = _token_scale_for_render(_grid_movement.token_scale())
	player_shadow.position = rendered_origin - TOKEN_OFFSET + blocked_offset * 0.35
	var foot_y: int = roundi(rendered_origin.y + TOKEN_FOOT_ANCHOR.y)
	player_shadow.z_index = foot_y - 1
	player_token.z_index = foot_y
	player_shadow.queue_redraw()
	_update_camera_for_token_origin(rendered_origin)


func _token_scale_for_render(movement_scale: Vector2) -> Vector2:
	return movement_scale * TOKEN_ASPECT_COMPENSATION
