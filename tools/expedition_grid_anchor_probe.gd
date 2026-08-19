extends Node

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const ExpeditionScreenScript := preload("res://src/expedition/expedition_screen.gd")
const MapStateScript := preload("res://src/expedition/expedition_map_state.gd")

const EXPECTED_VIEW_CELLS := Vector2i(13, 7)
var _failures: Array[String] = []


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var screen := (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	_check_grid_geometry(screen)
	_check_hero_anchors(screen)
	_check_shadow_motion(screen)
	_check_visibility_disabled(screen)
	_check_teleport_overlay_disabled(screen)

	if _failures.is_empty():
		print("EXPEDITION_GRID_ANCHOR_PROBE_PASS")
		get_tree().quit()
		return
	for failure: String in _failures:
		push_error("EXPEDITION_GRID_ANCHOR_PROBE: " + failure)
	get_tree().quit(1)


func _check_grid_geometry(screen: Control) -> void:
	var rendered_cell: float = (
			ExpeditionScreenScript.MAP_CELL * ExpeditionScreenScript.MAP_RENDER_SCALE)
	var view_cells := Vector2i(
			int(round(screen.map_view.size.x / rendered_cell)),
			int(round(screen.map_view.size.y / rendered_cell)))
	_expect(view_cells == EXPECTED_VIEW_CELLS,
			"view cells %s != %s" % [view_cells, EXPECTED_VIEW_CELLS])
	_expect(absf(screen.map_view.size.x / rendered_cell - EXPECTED_VIEW_CELLS.x) < 0.001,
			"view width cuts a cell")
	_expect(absf(screen.map_view.size.y / rendered_cell - EXPECTED_VIEW_CELLS.y) < 0.001,
			"view height cuts a cell")
	_expect(is_equal_approx(
			ExpeditionScreenScript.TOKEN_CELL_FOOT_POINT.x,
			ExpeditionScreenScript.MAP_CELL * 0.5),
			"foot contact point is not horizontally centered in its cell")
	_expect(ExpeditionScreenScript.TOKEN_SIZE.x > ExpeditionScreenScript.MAP_CELL,
			"token canvas must allow art to extend beyond one cell")

	var pool: Array[HeroData] = HeroDataScript.create_launch_pool()
	screen._on_hero_selected(pool[0])
	for cell: Vector2i in [Vector2i.ZERO, Vector2i(15, 9), Vector2i(31, 17)]:
		screen.map.player = cell
		screen._camera_initialized = false
		screen._update_map_camera()
		var offset: Vector2 = screen.map_world.position
		_expect(absf(offset.x / rendered_cell - round(offset.x / rendered_cell)) < 0.001,
				"camera x offset cuts a boundary cell at %s: %s" % [cell, offset.x])
		_expect(absf(offset.y / rendered_cell - round(offset.y / rendered_cell)) < 0.001,
				"camera y offset cuts a boundary cell at %s: %s" % [cell, offset.y])


func _check_hero_anchors(screen: Control) -> void:
	var reference_left: Vector2 = screen._token_canvas_point_for_source(
			ExpeditionScreenScript.H01_SOURCE_LEFT_FOOT)
	var reference_right: Vector2 = screen._token_canvas_point_for_source(
			ExpeditionScreenScript.H01_SOURCE_RIGHT_FOOT)
	_expect(absf((reference_left.x + reference_right.x) * 0.5
			- ExpeditionScreenScript.TOKEN_FOOT_ANCHOR.x) < 0.01,
			"h01 double-foot midpoint is not the token pivot")
	_expect(reference_left.y == reference_right.y,
			"h01 left and right feet do not share one baseline")
	for hero: HeroData in HeroDataScript.create_launch_pool():
		var source_frames := load(hero.sprite_frames_path) as SpriteFrames
		for frame_index: int in source_frames.get_frame_count(&"idle"):
			var source_image: Image = source_frames.get_frame_texture(
					&"idle", frame_index).get_image()
			_expect(source_image.get_size() == Vector2i(256, 256),
					"%s does not reuse h01 source coordinates" % hero.hero_id)
			_expect(_rect_has_alpha(source_image, Rect2i(110, 176, 14, 6)),
					"%s frame %d misses h01 left-foot region" % [hero.hero_id, frame_index])
			_expect(_rect_has_alpha(source_image, Rect2i(132, 176, 16, 6)),
					"%s frame %d misses h01 right-foot region" % [hero.hero_id, frame_index])
		screen.hero_idle_frames_path = hero.sprite_frames_path
		screen._apply_token_idle_art()
		for texture: Texture2D in screen._hero_idle_token_frames:
			_expect(texture.get_size() == Vector2(208, 208),
					"%s token canvas size differs" % hero.hero_id)
			var token_bounds: Rect2i = texture.get_image().get_used_rect()
			_expect(token_bounds.position.x > 0 and token_bounds.position.y > 0
					and token_bounds.end.x < 208 and token_bounds.end.y < 208,
					"%s token art touches its canvas edge" % hero.hero_id)
		_expect(screen._token_canvas_point_for_source(
				ExpeditionScreenScript.H01_SOURCE_LEFT_FOOT) == reference_left,
				"%s left foot differs from h01" % hero.hero_id)
		_expect(screen._token_canvas_point_for_source(
				ExpeditionScreenScript.H01_SOURCE_RIGHT_FOOT) == reference_right,
				"%s right foot differs from h01" % hero.hero_id)


func _check_shadow_motion(screen: Control) -> void:
	var script_source: String = FileAccess.get_file_as_string(
			"res://src/expedition/expedition_screen.gd")
	_expect("player_backdrop.draw_circle" in script_source,
			"player shadow is not a single ellipse")
	_expect(screen._player_shadow_width_at_lift(1.0)
			< screen._player_shadow_width_at_lift(0.0),
			"moving shadow does not contract under a lifted foot")
	_expect(screen._player_shadow_width_at_lift(0.0)
			== ExpeditionScreenScript.PLAYER_SHADOW_BASE_WIDTH,
			"standing shadow width changed unexpectedly")


func _check_visibility_disabled(screen: Control) -> void:
	_expect(not ExpeditionScreenScript.LIMITED_VISIBILITY_ENABLED,
			"limited visibility is still enabled")
	for y: int in MapStateScript.HEIGHT:
		for x: int in MapStateScript.WIDTH:
			var cell := Vector2i(x, y)
			_expect(screen._is_cell_visible(cell), "hidden cell remains at %s" % cell)
			_expect(screen._terrain_img.get_pixelv(cell).g > 0.99,
					"terrain visibility mask remains dark at %s" % cell)


func _check_teleport_overlay_disabled(screen: Control) -> void:
	_expect(screen.teleport_fx != null, "teleport compatibility layer is missing")
	_expect(not screen.teleport_fx.visible, "occupied teleport overlay is still visible")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _rect_has_alpha(image: Image, rect: Rect2i) -> bool:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a >= 0.38:
				return true
	return false
