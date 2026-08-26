extends SceneTree

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const LAYERS: Array[String] = [
	"MidgroundLeft",
	"MidgroundCenter",
	"MidgroundRight",
	"BattlePlatform",
	"ForegroundLeft",
	"ForegroundRight",
	"ForegroundCenterStone",
	"ForegroundCenterStone2",
	"ForegroundCenterStone3",
]


func _initialize() -> void:
	var packed := load(SCENE7_PATH) as PackedScene
	if packed == null:
		print("SCENE7_STAGE3_COMPOSITION: FAIL missing_scene")
		quit(1)
		return
	var stage := packed.instantiate()
	var visible_rects: Dictionary[String, Rect2] = {}
	for node_name: String in LAYERS:
		var layer := stage.get_node(node_name) as TextureRect
		var visible_rect := _scene7_platform_visible_rect(layer) \
				if node_name == "BattlePlatform" else _displayed_used_rect(layer)
		visible_rects[node_name] = visible_rect
		print(
			"SCENE7_STAGE3_LAYER: name=", node_name,
			" position=", layer.position,
			" size=", layer.size,
			" scale=", layer.scale,
			" visible=", visible_rect)
	var center := stage.get_node("MidgroundCenter") as TextureRect
	var left := stage.get_node("MidgroundLeft") as TextureRect
	var right := stage.get_node("MidgroundRight") as TextureRect
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var foreground_left := stage.get_node("ForegroundLeft") as TextureRect
	var foreground_right := stage.get_node("ForegroundRight") as TextureRect
	var foreground_center := stage.get_node("ForegroundCenterStone") as TextureRect
	var foreground_center2 := stage.get_node("ForegroundCenterStone2") as TextureRect
	var foreground_center3 := stage.get_node("ForegroundCenterStone3") as TextureRect
	var front_water := stage.get_node("FrontWater") as ColorRect
	var spring_contact := stage.get_node("PlatformSpringContact") as ColorRect
	var sky := stage.get_node("Sky") as TextureRect
	var center_rect: Rect2 = visible_rects["MidgroundCenter"]
	var left_rect: Rect2 = visible_rects["MidgroundLeft"]
	var right_rect: Rect2 = visible_rects["MidgroundRight"]
	var platform_rect: Rect2 = visible_rects["BattlePlatform"]
	var foreground_left_rect: Rect2 = visible_rects["ForegroundLeft"]
	var foreground_right_rect: Rect2 = visible_rects["ForegroundRight"]
	var foreground_center_rect: Rect2 = visible_rects["ForegroundCenterStone"]
	var left_overlap := left_rect.end.x - center_rect.position.x
	var right_overlap := center_rect.end.x - right_rect.position.x
	var foreground_opening := foreground_right_rect.position.x - foreground_left_rect.end.x
	var manual_stones_ready := true
	var manual_stone_contract := {
		"ForegroundCenterStone": [Vector2(74.0, 655.89087), Vector2(390.94336, 312.8302), 0.0],
		"ForegroundCenterStone2": [Vector2(319.0, 662.89087), Vector2(390.94336, 312.83014), 0.0],
		"ForegroundCenterStone3": [Vector2(349.99994, 891.8908), Vector2(390.94336, 312.8302), -0.3630285],
	}
	for node_name: String in manual_stone_contract:
		var stone := stage.get_node(node_name) as TextureRect
		var expected: Array = manual_stone_contract[node_name]
		manual_stones_ready = (
			manual_stones_ready
			and stone.position.is_equal_approx(expected[0])
			and stone.size.is_equal_approx(expected[1])
			and is_equal_approx(stone.rotation, float(expected[2]))
			and stone.scale == Vector2(2.65, 2.65))
	var passed := (
		stage.get_node_or_null("DaylightBackdrop") == null
		and sky.material == null
		and center.size.is_equal_approx(Vector2(522.2, 240.8))
		and left.size.is_equal_approx(Vector2(359.83334, 271.08334))
		and right.size.is_equal_approx(Vector2(352.4167, 251.0))
		and platform.size.is_equal_approx(Vector2(364.83334, 188.0))
		and foreground_left.size == foreground_left.texture.get_size()
		and foreground_right.size == foreground_right.texture.get_size()
		and is_equal_approx(center.scale.x, center.scale.y)
		and is_equal_approx(left.scale.x, left.scale.y)
		and is_equal_approx(right.scale.x, right.scale.y)
		and is_equal_approx(platform.scale.x, platform.scale.y)
		and is_equal_approx(foreground_left.scale.x, foreground_left.scale.y)
		and is_equal_approx(foreground_right.scale.x, foreground_right.scale.y)
		and is_equal_approx(foreground_center.scale.x, foreground_center.scale.y)
		and is_equal_approx(foreground_center2.scale.x, foreground_center2.scale.y)
		and is_equal_approx(foreground_center3.scale.x, foreground_center3.scale.y)
		and center.get_index() < left.get_index()
		and left.get_index() < right.get_index()
		and right.get_index() < front_water.get_index()
		and front_water.get_index() < spring_contact.get_index()
		and spring_contact.get_index() < platform.get_index()
		and platform.get_index() < foreground_left.get_index()
		and platform.get_index() < foreground_center.get_index()
		and platform.get_index() < foreground_center2.get_index()
		and platform.get_index() < foreground_center3.get_index()
		and manual_stones_ready
		and left_overlap >= 260.0 and left_overlap <= 320.0
		and right_overlap >= 150.0 and right_overlap <= 210.0
		and foreground_opening >= 820.0 and foreground_opening <= 880.0
		and left_rect.end.y >= 690.0 and left_rect.end.y <= 710.0
		and center_rect.end.y >= 700.0 and center_rect.end.y <= 720.0
		and right_rect.end.y >= 690.0 and right_rect.end.y <= 710.0
		and platform_rect.position.x < 0.0
		and platform_rect.end.x > 1920.0
		and is_equal_approx(platform_rect.position.y, 738.0)
		and is_equal_approx(platform_rect.size.y, 96.0)
		and platform_rect.end.y - front_water.position.y >= 4.0
		and platform_rect.end.y - front_water.position.y <= 10.0
		and spring_contact.position == Vector2(-32.0, 824.0)
		and spring_contact.size == Vector2(1984.0, 18.0))
	print(
		"SCENE7_STAGE3_COMPOSITION: ", "PASS" if passed else "FAIL",
		" left_overlap=", snappedf(left_overlap, 0.01),
		" right_overlap=", snappedf(right_overlap, 0.01),
		" foreground_opening=", snappedf(foreground_opening, 0.01),
		" rear_shore_y=", Vector3(left_rect.end.y, center_rect.end.y, right_rect.end.y),
		" platform_rect=", platform_rect,
		" foreground_center_rect=", foreground_center_rect,
		" manual_stones_ready=", manual_stones_ready,
		" front_underlap=", snappedf(platform_rect.end.y - front_water.position.y, 0.01))
	stage.free()
	quit(0 if passed else 1)


func _displayed_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var source_size := layer.texture.get_size()
	var stretch_ratio := Vector2(
		layer.size.x / source_size.x,
		layer.size.y / source_size.y)
	return Rect2(
		layer.position + Vector2(used_rect.position) * stretch_ratio * layer.scale,
		Vector2(used_rect.size) * stretch_ratio * layer.scale)


func _scene7_platform_visible_rect(layer: TextureRect) -> Rect2:
	var source_rect := _alpha_used_rect(layer.texture.get_image(), 0.5)
	var material := layer.material as ShaderMaterial
	var surface_bottom_row: float = material.get_shader_parameter("surface_bottom_row")
	var shallow_wall_rows: float = material.get_shader_parameter("shallow_wall_rows")
	var edge_variation_rows: float = material.get_shader_parameter("edge_variation_rows")
	var visible_source_bottom := minf(
			float(source_rect.end.y),
			surface_bottom_row + shallow_wall_rows + edge_variation_rows)
	var visible_source_rect := Rect2(
			Vector2(source_rect.position),
			Vector2(source_rect.size.x,
					visible_source_bottom - float(source_rect.position.y)))
	var stretch_ratio := layer.size / Vector2(layer.texture.get_size())
	return Rect2(
			layer.position + visible_source_rect.position * stretch_ratio * layer.scale,
			visible_source_rect.size * stretch_ratio * layer.scale)


func _alpha_used_rect(image: Image, threshold: float) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
