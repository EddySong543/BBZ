extends SceneTree

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")
const FAR_MOUNTAIN_PATH := "res://assets/scenes/scene8/scene8_far_mountain.png"
const CENTER_SNOW_PATH := (
		"res://assets/scenes/scene8/scene8_foreground_center_snow.png")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := SCENE8.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame

	var distant := stage.get_node_or_null("FarMountainDistant") as Sprite2D
	var middle := stage.get_node_or_null("FarMountainMiddle") as Sprite2D
	var shoreline := stage.get_node_or_null("FarSnowfield") as TextureRect
	var center_snow := stage.get_node_or_null("ForegroundCenterSnow") as TextureRect
	var mountain_metrics := _probe_mountain_depth(
			stage, distant, middle, shoreline)
	var snow_metrics := _probe_center_snow(stage, center_snow)
	var passed := bool(mountain_metrics["passed"]) and bool(snow_metrics["passed"])
	print(
			"SCENE8_DEPTH_PROBE: ", "PASS" if passed else "FAIL",
			" mountain=", mountain_metrics,
			" center_snow=", snow_metrics)
	stage.queue_free()
	quit(0 if passed else 1)


func _probe_mountain_depth(
		stage: BattleStage,
		distant: Sprite2D,
		middle: Sprite2D,
		shoreline: TextureRect) -> Dictionary:
	if distant == null or middle == null or shoreline == null:
		return {"passed": false, "reason": "missing mountain layer"}
	var distant_rect := _sprite_used_rect(distant)
	var middle_rect := _sprite_used_rect(middle)
	var shoreline_rect := _texture_rect_used_rect(shoreline)
	var factors := Vector3(
			float(distant.get_meta("parallax_factor")),
			float(middle.get_meta("parallax_factor")),
			float(shoreline.get_meta("parallax_factor")))
	var source_shared := (
			distant.texture.resource_path == FAR_MOUNTAIN_PATH
			and middle.texture.resource_path == FAR_MOUNTAIN_PATH
			and shoreline.texture.resource_path == FAR_MOUNTAIN_PATH)
	var vertical_steps := Vector2(
			middle_rect.position.y - distant_rect.position.y,
			shoreline_rect.position.y - middle_rect.position.y)
	var full_width := (
			distant_rect.position.x <= 0.0 and distant_rect.end.x >= 1920.0
			and middle_rect.position.x <= 0.0 and middle_rect.end.x >= 1920.0)
	var ordered := (
			stage.get_node("AuroraReflection").get_index() < distant.get_index()
			and distant.get_index() < middle.get_index()
			and middle.get_index() < shoreline.get_index())
	var passed := (
			source_shared and distant.flip_h and not middle.flip_h
			and factors.x < factors.y and factors.y < factors.z
			and vertical_steps.x >= 24.0 and vertical_steps.y >= 24.0
			and distant_rect.end.y < middle_rect.end.y
			and middle_rect.end.y < shoreline_rect.end.y
			and full_width and ordered)
	return {
		"passed": passed,
		"source_shared": source_shared,
		"distant_flipped": distant.flip_h,
		"parallax_factors": factors,
		"ridge_top_y": Vector3(
				distant_rect.position.y,
				middle_rect.position.y,
				shoreline_rect.position.y),
		"ridge_bottom_y": Vector3(
				distant_rect.end.y,
				middle_rect.end.y,
				shoreline_rect.end.y),
		"vertical_steps": vertical_steps,
		"full_width": full_width,
		"ordered": ordered,
	}


func _probe_center_snow(stage: BattleStage, center_snow: TextureRect) -> Dictionary:
	if center_snow == null or center_snow.texture == null:
		return {"passed": false, "reason": "missing center snow"}
	var image := center_snow.texture.get_image()
	var used_rect := _alpha_used_rect(image, 0.03)
	var screen_rect := _texture_rect_used_rect(center_snow)
	var opaque_count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= 0.03:
				opaque_count += 1
	var coverage := float(opaque_count) / float(image.get_width() * image.get_height())
	var layer_order := (
			stage.get_node("BattlePlatform").get_index() < center_snow.get_index()
			and center_snow.get_index() < stage.get_node("ForegroundLeft").get_index())
	var passed := (
			center_snow.texture.resource_path == CENTER_SNOW_PATH
			and center_snow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and used_rect.size.x >= 280 and used_rect.size.y >= 60
			and coverage >= 0.18 and coverage <= 0.24
			and is_equal_approx(center_snow.rotation, PI)
			and screen_rect.position.x >= -40.0 and screen_rect.position.x <= 0.0
			and screen_rect.end.x >= 1870.0 and screen_rect.end.x <= 1890.0
			and screen_rect.position.y >= 945.0 and screen_rect.position.y <= 970.0
			and screen_rect.end.y >= 1340.0 and screen_rect.end.y <= 1370.0
			and float(center_snow.get_meta("parallax_factor")) > 1.18
			and layer_order)
	return {
		"passed": passed,
		"texture_path": center_snow.texture.resource_path,
		"source_used_rect": used_rect,
		"screen_used_rect": screen_rect,
		"alpha_coverage": snappedf(coverage, 0.0001),
		"parallax_factor": float(center_snow.get_meta("parallax_factor")),
		"layer_order": layer_order,
	}


func _texture_rect_used_rect(layer: TextureRect) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.03)
	var source_to_node := layer.size / Vector2(layer.texture.get_size())
	var local_rect := Rect2(
			Vector2(used_rect.position) * source_to_node,
			Vector2(used_rect.size) * source_to_node)
	var layer_transform := Transform2D(
			layer.rotation, layer.scale, 0.0, layer.position)
	var corners: Array[Vector2] = [
		layer_transform * local_rect.position,
		layer_transform * Vector2(local_rect.end.x, local_rect.position.y),
		layer_transform * local_rect.end,
		layer_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum := corners[0]
	var maximum := corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func _sprite_used_rect(layer: Sprite2D) -> Rect2:
	var used_rect := _alpha_used_rect(layer.texture.get_image(), 0.03)
	var left := float(used_rect.position.x)
	if layer.flip_h:
		left = float(layer.texture.get_width() - used_rect.end.x)
	return Rect2(
			layer.position + Vector2(left, used_rect.position.y) * layer.scale,
			Vector2(used_rect.size) * layer.scale)


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
