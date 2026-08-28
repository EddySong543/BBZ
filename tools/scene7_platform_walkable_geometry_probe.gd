extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const SAMPLE_SCREEN_X_MIN: float = 800.0
const SAMPLE_SCREEN_X_MAX: float = 1120.0
const SAMPLE_SCREEN_X_STEP: float = 40.0
const ALPHA_THRESHOLD: float = 0.5


func _initialize() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var texture := platform.texture
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Scene7 platform image is unavailable")
		stage.free()
		quit(1)
		return

	var screen_bounds: Array[Vector2] = []
	var sample_x := SAMPLE_SCREEN_X_MIN
	while sample_x <= SAMPLE_SCREEN_X_MAX:
		var image_x := _screen_x_to_image_x(sample_x, platform, image)
		var image_bounds := _opaque_y_bounds(image, image_x)
		if image_bounds.x >= 0.0:
			screen_bounds.append(Vector2(
					_image_y_to_screen_y(image_bounds.x, platform, image),
					_image_y_to_screen_y(image_bounds.y + 1.0, platform, image)))
		sample_x += SAMPLE_SCREEN_X_STEP

	var top_min := INF
	var top_max := -INF
	var bottom_min := INF
	var bottom_max := -INF
	for bounds: Vector2 in screen_bounds:
		top_min = minf(top_min, bounds.x)
		top_max = maxf(top_max, bounds.x)
		bottom_min = minf(bottom_min, bounds.y)
		bottom_max = maxf(bottom_max, bounds.y)

	var passed := not screen_bounds.is_empty() \
			and top_max < 760.0 and bottom_min > 824.0
	print(
			"SCENE7_PLATFORM_WALKABLE_GEOMETRY: ",
			"PASS" if passed else "FAIL",
			" image_size=", image.get_size(),
			" rect=", platform.get_rect(),
			" scale=", platform.scale,
			" center_band_opaque_top=", Vector2(top_min, top_max),
			" center_band_opaque_bottom=", Vector2(bottom_min, bottom_max),
			" samples=", screen_bounds)
	stage.free()
	quit(0 if passed else 1)


func _screen_x_to_image_x(
		screen_x: float, platform: TextureRect, image: Image) -> int:
	var local_x := (screen_x - platform.position.x) / platform.scale.x
	var normalized_x := clampf(local_x / platform.size.x, 0.0, 1.0)
	return clampi(
			floori(normalized_x * float(image.get_width())),
			0,
			image.get_width() - 1)


func _image_y_to_screen_y(
		image_y: float, platform: TextureRect, image: Image) -> float:
	var normalized_y := image_y / float(image.get_height())
	return platform.position.y + normalized_y * platform.size.y * platform.scale.y


func _opaque_y_bounds(image: Image, image_x: int) -> Vector2:
	var first_y := -1
	var last_y := -1
	for image_y: int in image.get_height():
		if image.get_pixel(image_x, image_y).a < ALPHA_THRESHOLD:
			continue
		if first_y < 0:
			first_y = image_y
		last_y = image_y
	return Vector2(first_y, last_y)
