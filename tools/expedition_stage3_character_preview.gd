extends Node

## 第三阶段角色落地预览：同一真实地图/镜头下比较2px与3px屏幕颗粒。
## 角色使用统一脚底基线，接触反馈为硬像素短影与地表压痕，不恢复四角格强调。

const HeroDataScript := preload("res://src/battle/hero_data.gd")
const MapState := preload("res://src/expedition/expedition_map_state.gd")
const ProbeOutput := preload("res://tools/probe_output.gd")

const HERO_IDS: Array[String] = ["h01", "h05", "h19", "h24"]
const HERO_CELLS: Array[Vector2i] = [
	Vector2i(7, 5), Vector2i(10, 5), Vector2i(7, 8), Vector2i(10, 8),
]
const TOKEN_WORLD_SIZE := Vector2(96, 96)
const TOKEN_OFFSET := Vector2(12, 12)
const CLOSEUP_RECT := Rect2i(720, 180, 480, 540)

var _screen: Control
var _heroes: Array[HeroData] = []
var _preview_tokens: Array[TextureRect] = []
var _contact_layer: Control


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1920, 1080)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_collect_heroes()

	_screen = (load("res://src/expedition/expedition_screen.tscn") as PackedScene).instantiate()
	add_child(_screen)
	await get_tree().create_timer(0.35).timeout
	_screen.seed_value = 777
	_screen._on_hero_selected(_heroes[0])
	await get_tree().create_timer(0.45).timeout
	for y: int in MapState.HEIGHT:
		for x: int in MapState.WIDTH:
			var cell := Vector2i(x, y)
			_screen.map.revealed[cell] = true
			_screen.map.visible[cell] = true
	_screen.map.player = Vector2i(9, 7)
	_screen.foliage_art.visible = false
	_screen.object_art.visible = false
	_screen.marker_art.visible = false
	_screen.canvas.visible = false
	_screen._set_player_visual_visible(false)
	_screen._camera_initialized = false
	_screen._refresh()
	await get_tree().create_timer(0.25).timeout
	_screen.set_process(false)

	_contact_layer = Control.new()
	_contact_layer.name = "Stage3ContactPreview"
	_contact_layer.size = _screen.MAP_WORLD_SIZE
	_contact_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contact_layer.draw.connect(_draw_contact_feedback)
	_screen.map_world.add_child(_contact_layer)
	_build_preview_tokens()

	await _capture_grain(36, 32, 33, "exped_stage3_character_grain_2px.png")
	await _capture_grain(24, 21, 22, "exped_stage3_character_grain_3px.png")
	_build_closeup_comparison()
	get_tree().quit()


func _collect_heroes() -> void:
	var by_id: Dictionary = {}
	for hero: HeroData in HeroDataScript.create_launch_pool():
		by_id[hero.hero_id] = hero
	for hero_id: String in HERO_IDS:
		assert(by_id.has(hero_id), hero_id)
		_heroes.append(by_id[hero_id])


func _build_preview_tokens() -> void:
	for index: int in HERO_IDS.size():
		var token := TextureRect.new()
		token.name = "Stage3Token_%s" % HERO_IDS[index]
		token.position = Vector2(HERO_CELLS[index] * 120) + TOKEN_OFFSET
		token.size = TOKEN_WORLD_SIZE
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.map_world.add_child(token)
		_preview_tokens.append(token)


func _capture_grain(
		canvas_px: int,
		content_max_px: int,
		foot_baseline_px: int,
		file_name: String) -> void:
	for index: int in _heroes.size():
		_preview_tokens[index].texture = _build_foot_anchored_token(
				_heroes[index], canvas_px, content_max_px, foot_baseline_px)
	_contact_layer.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var output_path := ProbeOutput.path(file_name)
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	var error := image.save_png(output_path)
	assert(error == OK, error_string(error))
	print("saved: ", output_path)


func _build_foot_anchored_token(
		hero: HeroData,
		canvas_px: int,
		content_max_px: int,
		foot_baseline_px: int) -> Texture2D:
	var frames := load(hero.sprite_frames_path) as SpriteFrames
	assert(frames != null and frames.has_animation(&"idle"), hero.hero_id)
	var frame_count := frames.get_frame_count(&"idle")
	var merged_bounds := Rect2i()
	for frame_index: int in frame_count:
		var image: Image = frames.get_frame_texture(&"idle", frame_index).get_image()
		var bounds := image.get_used_rect()
		if bounds.has_area():
			merged_bounds = bounds if not merged_bounds.has_area() else merged_bounds.merge(bounds)
	assert(merged_bounds.has_area(), hero.hero_id)

	var source: Image = frames.get_frame_texture(&"idle", 0).get_image()
	source.convert(Image.FORMAT_RGBA8)
	var cropped := source.get_region(merged_bounds)
	var longest_axis := maxi(merged_bounds.size.x, merged_bounds.size.y)
	var scale := float(content_max_px) / float(longest_axis)
	var scaled_size := Vector2i(
		maxi(1, int(round(merged_bounds.size.x * scale))),
		maxi(1, int(round(merged_bounds.size.y * scale))))
	cropped.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_NEAREST)
	var output := Image.create(canvas_px, canvas_px, false, Image.FORMAT_RGBA8)
	var origin := Vector2i(
		int(round((canvas_px - scaled_size.x) * 0.5)),
		foot_baseline_px - scaled_size.y)
	assert(origin.x >= 0 and origin.y >= 0, hero.hero_id)
	output.blit_rect(cropped, Rect2i(Vector2i.ZERO, scaled_size), origin)
	return ImageTexture.create_from_image(output)


func _draw_contact_feedback() -> void:
	for index: int in HERO_CELLS.size():
		var cell := HERO_CELLS[index]
		var center := Vector2(cell * 120) + Vector2(60, 100)
		var terrain: int = int(_screen._ground_terrain_at(cell))
		var shadow := Color(0.08, 0.12, 0.07, 0.52)
		var press := Color(0.18, 0.29, 0.12, 0.72)
		if terrain == 1:
			shadow = Color(0.22, 0.12, 0.04, 0.48)
			press = Color(0.46, 0.25, 0.08, 0.66)
		_contact_layer.draw_rect(Rect2(center + Vector2(-16, 0), Vector2(32, 4)), Color(shadow, 0.82))
		_contact_layer.draw_rect(Rect2(center + Vector2(-10, -4), Vector2(20, 4)), Color(shadow, 0.52))
		_contact_layer.draw_rect(Rect2(center + Vector2(-22, 0), Vector2(4, 4)), Color(press, 0.72))
		_contact_layer.draw_rect(Rect2(center + Vector2(18, 0), Vector2(4, 4)), Color(press, 0.72))


func _build_closeup_comparison() -> void:
	var left := Image.load_from_file(ProbeOutput.path("exped_stage3_character_grain_2px.png"))
	var right := Image.load_from_file(ProbeOutput.path("exped_stage3_character_grain_3px.png"))
	assert(left != null and right != null)
	left = left.get_region(CLOSEUP_RECT)
	right = right.get_region(CLOSEUP_RECT)
	left.resize(960, 1080, Image.INTERPOLATE_NEAREST)
	right.resize(960, 1080, Image.INTERPOLATE_NEAREST)
	left.convert(Image.FORMAT_RGBA8)
	right.convert(Image.FORMAT_RGBA8)
	var comparison := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	comparison.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	comparison.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(960, 0))
	var output_path := ProbeOutput.path("exped_stage3_character_grain_compare.png")
	var error := comparison.save_png(output_path)
	assert(error == OK, error_string(error))
	print("saved: ", output_path)
