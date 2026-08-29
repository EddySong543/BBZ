extends SceneTree

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")
const SCENE8_PATH := "res://src/ui/scenes/scene8.tscn"
const RETIRED_SNOWFALL_SCRIPT_PATH := (
		"res://src/ui/components/scene8_snowfall_field.gd")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := SCENE8.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	var failures: Array[String] = []
	var far := stage.get_node_or_null("SnowMotesFar") as GPUParticles2D
	var near := stage.get_node_or_null("SnowMotesNear") as GPUParticles2D
	if far == null or near == null:
		failures.append("missing SnowMotesFar/SnowMotesNear")
		_finish(stage, failures, {})
		return
	var far_process := far.process_material as ParticleProcessMaterial
	var near_process := near.process_material as ParticleProcessMaterial
	var texture := far.texture as GradientTexture2D
	var blend := far.material as CanvasItemMaterial
	_check(far_process != null and near_process != null,
			"particle process materials missing", failures)
	_check(texture != null and far.texture == near.texture,
			"shared Scene3-style gradient texture missing", failures)
	_check(blend != null and blend.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"Scene3-style additive blend missing", failures)
	_check(far.amount == 9 and near.amount == 6,
			"Scene3-style sparse 9+6 count missing", failures)
	_check(far.emitting and near.emitting and far.interpolate and near.interpolate,
			"particle runtime emission/interpolation disabled", failures)
	_check(far.fixed_fps == 30 and near.fixed_fps == 30,
			"Scene3 fixed-FPS particle cadence is missing", failures)
	_check(is_equal_approx(far.lifetime, 11.0)
			and is_equal_approx(far.preprocess, 8.0)
			and is_equal_approx(near.lifetime, 8.0)
			and is_equal_approx(near.preprocess, 5.0),
			"Scene3-style lifetime/preprocess values missing", failures)
	var texture_metrics := _measure_visible_texture_core(texture)
	_check(bool(texture_metrics.get("available", false))
			and int(texture_metrics.get("width", 0)) == 8
			and int(texture_metrics.get("height", 0)) == 8,
			"snow mote texture pixel data invalid", failures)
	var far_travel := Vector2.ZERO
	var near_travel := Vector2.ZERO
	if far_process != null and near_process != null:
		_check(far_process.resource_local_to_scene
				and near_process.resource_local_to_scene,
				"snow materials must remain Scene8-local", failures)
		_check(far_process.direction.y > 0.95 and near_process.direction.y > 0.95,
				"snow motes must descend", failures)
		_check(far_process.initial_velocity_max
				< near_process.initial_velocity_min,
				"far and near velocity bands overlap", failures)
		_check(far_process.scale_max < near_process.scale_min,
				"far and near scale bands overlap", failures)
		_check(is_equal_approx(far_process.scale_min, 0.5)
				and is_equal_approx(far_process.scale_max, 1.05)
				and is_equal_approx(near_process.scale_min, 1.35)
				and is_equal_approx(near_process.scale_max, 2.25),
				"particle scale bands diverge from Scene3", failures)
		_check(far_process.emission_box_extents == Vector3(430, 170, 1)
				and near_process.emission_box_extents == Vector3(390, 145, 1),
				"emission boxes diverge from Scene3", failures)
		_check(far_process.color.b > far_process.color.r
				and near_process.color.g > near_process.color.r,
				"cold-blue/aurora-green depth palette missing", failures)
		_check(_has_scene3_life_fade(far_process.color_ramp)
				and far_process.color_ramp == near_process.color_ramp,
				"Scene3-style lifecycle fade missing", failures)
		far_travel = _estimated_vertical_travel(far_process, 2.0)
		near_travel = _estimated_vertical_travel(near_process, 2.0)
		_check(far_travel.x >= 6.0 and far_travel.y <= 12.0
				and near_travel.x >= 13.0 and near_travel.y <= 23.0,
				"downward motion diverges from Scene3 cadence", failures)
	_check(stage.get_node("FarGlacier").get_index() < far.get_index()
			and far.get_index()
			< stage.get_node("PlatformWaterContact").get_index(),
			"far snow layer order is incorrect", failures)
	_check(stage.get_node("BattlePlatform").get_index() < near.get_index()
			and near.get_index()
			< stage.get_node("ForegroundSnowfield").get_index(),
			"near snow layer order is incorrect", failures)
	_check(_meta_close(far, "pointer_parallax_factor", 0.08)
			and _meta_close(near, "pointer_parallax_factor", 1.04),
			"snow pointer parallax is incorrect", failures)
	var scene_source := FileAccess.get_file_as_string(SCENE8_PATH)
	_check(not ResourceLoader.exists(RETIRED_SNOWFALL_SCRIPT_PATH)
			and not scene_source.contains("SnowfallFar")
			and not scene_source.contains("SnowfallNear")
			and not scene_source.contains("scene8_snowfall_field.gd"),
			"retired procedural snowfall remains", failures)
	_finish(stage, failures, {
		"amounts": Vector2i(far.amount, near.amount),
		"texture": texture_metrics,
		"far_scale": Vector2(far_process.scale_min, far_process.scale_max),
		"near_scale": Vector2(near_process.scale_min, near_process.scale_max),
		"far_velocity": Vector2(
				far_process.initial_velocity_min, far_process.initial_velocity_max),
		"near_velocity": Vector2(
				near_process.initial_velocity_min, near_process.initial_velocity_max),
		"estimated_far_down_2s": far_travel,
		"estimated_near_down_2s": near_travel,
		"alpha": Vector2(far_process.color.a, near_process.color.a),
	})


func _estimated_vertical_travel(
		material: ParticleProcessMaterial,
		duration_sec: float) -> Vector2:
	var gravity_distance := 0.5 * material.gravity.y \
			* duration_sec * duration_sec
	return Vector2(
			material.initial_velocity_min * duration_sec + gravity_distance,
			material.initial_velocity_max * duration_sec + gravity_distance)


func _measure_visible_texture_core(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {"available": false}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"available": false}
	var minimum_x := image.get_width()
	var maximum_x := -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.1:
				continue
			minimum_x = mini(minimum_x, x)
			maximum_x = maxi(maximum_x, x)
	return {
		"available": maximum_x >= minimum_x,
		"width": image.get_width(),
		"height": image.get_height(),
		"core_width_px": maximum_x - minimum_x + 1,
	}


func _has_scene3_life_fade(ramp: Texture2D) -> bool:
	if not ramp is GradientTexture1D:
		return false
	var gradient := (ramp as GradientTexture1D).gradient
	if gradient == null or gradient.get_point_count() != 4:
		return false
	return gradient.get_color(0).a <= 0.01 \
			and gradient.get_color(1).a >= 0.95 \
			and gradient.get_color(2).a >= 0.8 \
			and gradient.get_color(3).a <= 0.01


func _meta_close(node: Node, key: StringName, expected: float) -> bool:
	return is_equal_approx(float(node.get_meta(key, -99.0)), expected)


func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(stage: Node, failures: Array[String], metrics: Dictionary) -> void:
	var passed := failures.is_empty()
	print("SCENE8_SNOW_MOTES_PROBE: ", "PASS" if passed else "FAIL",
			" metrics=", metrics, " failures=", failures)
	stage.queue_free()
	quit(0 if passed else 1)
