extends SceneTree

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")
const FAR_MOUNTAIN_PATH := "res://assets/scenes/scene8/scene8_far_mountain.png"
const FAR_GLACIER_PATH := "res://assets/scenes/scene8/scene8_far_glacier.png"
const FAR_MOUNTAIN_LEFT_PATH := (
		"res://assets/scenes/scene8/scene8_far_mountain_left.png")
const FAR_MOUNTAIN_RIGHT_PATH := (
		"res://assets/scenes/scene8/scene8_far_mountain_right.png")
const FOREGROUND_SNOWFIELD_PATH := (
		"res://assets/scenes/scene8/scene8_foreground_snowfield.png")
const FAR_DEPTH_GRADE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_far_depth_grade.gdshader")
const FOREGROUND_GRADE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_foreground_grade.gdshader")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := SCENE8.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame

	var shoreline := stage.get_node_or_null("FarSnowfield") as TextureRect
	var shoreline_secondary := (
			stage.get_node_or_null("FarSnowfield2") as TextureRect)
	var far_glacier := stage.get_node_or_null("FarGlacier") as TextureRect
	var far_left := stage.get_node_or_null("FarMountainLeft") as TextureRect
	var far_right := stage.get_node_or_null("FarMountainRight") as TextureRect
	var foreground_snow := stage.get_node_or_null("ForegroundSnowfield") as TextureRect
	var foreground_left := stage.get_node_or_null("ForegroundLeft") as TextureRect
	var foreground_right := stage.get_node_or_null("ForegroundRight") as TextureRect
	var composition_metrics := _probe_current_composition(
			stage, shoreline, shoreline_secondary,
			far_glacier, far_left, far_right, foreground_snow)
	var grade_metrics := _probe_depth_grade(
			shoreline, shoreline_secondary, far_glacier, far_left, far_right)
	var foreground_metrics := _probe_foreground_grade(
			foreground_snow, foreground_left, foreground_right)
	var joint_metrics := _probe_joint_balance(grade_metrics, foreground_metrics)
	var pointer_metrics := _probe_pointer_parallax(stage)
	var passed := (
			bool(composition_metrics["passed"])
			and bool(grade_metrics["passed"])
			and bool(foreground_metrics["passed"])
			and bool(joint_metrics["passed"])
			and bool(pointer_metrics["passed"]))
	print(
			"SCENE8_DEPTH_PROBE: ", "PASS" if passed else "FAIL",
			" composition=", composition_metrics,
			" grade=", grade_metrics,
			" foreground=", foreground_metrics,
			" joint=", joint_metrics,
			" pointer=", pointer_metrics)
	stage.queue_free()
	quit(0 if passed else 1)


func _probe_current_composition(
		stage: BattleStage,
		shoreline: TextureRect,
		shoreline_secondary: TextureRect,
		far_glacier: TextureRect,
		far_left: TextureRect,
		far_right: TextureRect,
		foreground_snow: TextureRect) -> Dictionary:
	if (shoreline == null or shoreline_secondary == null
			or far_glacier == null or far_left == null or far_right == null
			or foreground_snow == null):
		return {"passed": false, "reason": "missing current manual layer"}
	var left_rect := _texture_rect_used_rect(far_left)
	var right_rect := _texture_rect_used_rect(far_right)
	var shoreline_rect := _texture_rect_used_rect(shoreline)
	var secondary_rect := _texture_rect_used_rect(shoreline_secondary)
	var glacier_rect := _texture_rect_used_rect(far_glacier)
	var foreground_rect := _texture_rect_used_rect(foreground_snow)
	var far_paths := (
			far_left.texture.resource_path == FAR_MOUNTAIN_LEFT_PATH
			and far_right.texture.resource_path == FAR_MOUNTAIN_RIGHT_PATH
			and shoreline.texture.resource_path == FAR_MOUNTAIN_PATH
			and shoreline_secondary.texture.resource_path == FAR_MOUNTAIN_PATH
			and far_glacier.texture.resource_path == FAR_GLACIER_PATH)
	var mountain_coverage := (
			left_rect.position.x <= 5.0
			and left_rect.end.x >= 900.0
			and right_rect.position.x >= 995.0
			and right_rect.position.x <= 1010.0
			and right_rect.end.x >= 1950.0
			and shoreline_rect.position.x <= -9.0
			and shoreline_rect.end.x >= 870.0
			and secondary_rect.position.x <= 770.0
			and secondary_rect.end.x >= 1700.0
			and glacier_rect.position.x <= 0.0
			and glacier_rect.end.x >= 1920.0
			and left_rect.position.y >= 330.0 and left_rect.end.y <= 540.0
			and right_rect.position.y >= 325.0 and right_rect.end.y <= 530.0
			and shoreline_rect.position.y >= 390.0 and shoreline_rect.end.y <= 565.0
			and secondary_rect.position.y >= 370.0 and secondary_rect.end.y <= 570.0
			and glacier_rect.position.y >= 460.0 and glacier_rect.end.y <= 575.0)
	var foreground_coverage := (
			foreground_rect.position.x >= 0.0 and foreground_rect.position.x <= 10.0
			and foreground_rect.end.x >= 1900.0 and foreground_rect.end.x <= 1930.0
			and foreground_rect.position.y >= 930.0 and foreground_rect.position.y <= 970.0
			and foreground_rect.end.y >= 1240.0 and foreground_rect.end.y <= 1280.0)
	var ordered := (
			stage.get_node("AuroraReflection").get_index() < far_left.get_index()
			and far_left.get_index() < shoreline_secondary.get_index()
			and shoreline_secondary.get_index() < far_right.get_index()
			and far_right.get_index() < shoreline.get_index()
			and shoreline.get_index() < far_glacier.get_index()
			and stage.get_node("BattlePlatform").get_index() < foreground_snow.get_index()
			and foreground_snow.get_index() < stage.get_node("ForegroundLeft").get_index())
	var passed := (
			far_paths and mountain_coverage
			and foreground_snow.texture.resource_path == FOREGROUND_SNOWFIELD_PATH
			and foreground_snow.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and not stage.has_node("FarMountainDistant")
			and not stage.has_node("FarMountainMiddle")
			and not stage.has_node("ForegroundCenterSnow")
			and foreground_coverage and ordered)
	return {
		"passed": passed,
		"far_paths": far_paths,
		"mountain_bounds": {
			"left": left_rect,
			"right": right_rect,
			"shoreline": shoreline_rect,
			"shoreline_secondary": secondary_rect,
			"glacier": glacier_rect,
		},
		"mountain_coverage": mountain_coverage,
		"foreground_path": foreground_snow.texture.resource_path,
		"foreground_bounds": foreground_rect,
		"foreground_coverage": foreground_coverage,
		"manual_simplification": (
				not stage.has_node("FarMountainDistant")
				and not stage.has_node("FarMountainMiddle")
				and not stage.has_node("ForegroundCenterSnow")),
		"ordered": ordered,
	}


func _probe_pointer_parallax(stage: BattleStage) -> Dictionary:
	var expected := {
		"Sky": 0.0,
		"Stars": 0.0,
		"PixelAurora": 0.0,
		"FarGlacier": 0.06,
		"SnowMotesFar": 0.08,
		"FarMountainLeft": 0.08,
		"FarMountainRight": 0.08,
		"FarSnowfield": 0.10,
		"FarSnowfield2": 0.10,
		"MirrorLake": 1.0,
		"AuroraReflection": 1.0,
		"PlatformWaterContact": 1.0,
		"BattlePlatform": 1.0,
		"SnowMotesNear": 1.04,
		"ForegroundSnowfield": 1.08,
		"ForegroundLeft": 1.08,
		"ForegroundRight": 1.08,
	}
	var cached_layers := stage.get("_layers") as Array
	var cached_factors := stage.get("_pointer_factors") as PackedFloat32Array
	var runtime_factors := {}
	for index: int in cached_layers.size():
		var layer := cached_layers[index] as CanvasItem
		runtime_factors[String(layer.name)] = float(cached_factors[index])
	var runtime_matches := true
	for node_name: String in expected:
		runtime_matches = runtime_matches \
				and runtime_factors.has(node_name) \
				and is_equal_approx(
						float(runtime_factors.get(node_name, -1.0)),
						float(expected[node_name]))
	var water_factors := [
		float(runtime_factors.get("MirrorLake", -1.0)),
		float(runtime_factors.get("AuroraReflection", -1.0)),
		float(runtime_factors.get("PlatformWaterContact", -1.0)),
		float(runtime_factors.get("BattlePlatform", -1.0)),
	]
	var water_locked := true
	for factor: float in water_factors:
		water_locked = water_locked and is_equal_approx(factor, 1.0)
	var far_split_px := (
			float(expected["FarSnowfield"])
			- float(expected["FarGlacier"])) * stage.pointer_strength
	var foreground_extra_px := (
			float(expected["ForegroundLeft"])
			- float(expected["BattlePlatform"])) * stage.pointer_strength
	var shared_script := (stage.get_script() as Script).resource_path \
			== "res://src/ui/components/battle_stage.gd"
	return {
		"passed": (
				runtime_matches and water_locked and shared_script
				and is_equal_approx(stage.pointer_strength, 2.0)
				and is_equal_approx(stage.pointer_smooth, 6.0)
				and is_zero_approx(stage.pointer_zoom)
				and far_split_px <= 0.081
				and foreground_extra_px <= 0.161),
		"runtime_matches": runtime_matches,
		"water_locked": water_locked,
		"shared_script": shared_script,
		"pointer_strength": stage.pointer_strength,
		"pointer_smooth": stage.pointer_smooth,
		"pointer_zoom": stage.pointer_zoom,
		"far_split_px": snappedf(far_split_px, 0.001),
		"foreground_extra_px": snappedf(foreground_extra_px, 0.001),
		"runtime_factors": runtime_factors,
	}


func _probe_depth_grade(
		shoreline: TextureRect,
		shoreline_secondary: TextureRect,
		far_glacier: TextureRect,
		far_left: TextureRect,
		far_right: TextureRect) -> Dictionary:
	var layers := {
		"glacier": far_glacier,
		"left": far_left,
		"right": far_right,
		"shoreline": shoreline,
		"shoreline_secondary": shoreline_secondary,
	}
	var metrics := {}
	var materials_valid := true
	for role: String in layers:
		var layer := layers[role] as TextureRect
		var material := layer.material as ShaderMaterial
		if (material == null or material.shader == null
				or material.shader.resource_path != FAR_DEPTH_GRADE_SHADER_PATH):
			materials_valid = false
			metrics[role] = {"valid": false}
			continue
		metrics[role] = _measure_layer_grade(layer, material)

	if not materials_valid:
		return {"passed": false, "materials": metrics}
	var glacier := metrics["glacier"] as Dictionary
	var left := metrics["left"] as Dictionary
	var right := metrics["right"] as Dictionary
	var shore := metrics["shoreline"] as Dictionary
	var shore_secondary := metrics["shoreline_secondary"] as Dictionary
	var ordered_depth := (
			float(glacier["distance_mix"]) > float(left["distance_mix"])
			and float(glacier["distance_mix"]) > float(right["distance_mix"])
			and float(left["distance_mix"]) > float(shore["distance_mix"])
			and float(right["distance_mix"]) > float(shore["distance_mix"])
			and is_equal_approx(
					float(shore_secondary["distance_mix"]),
					float(shore["distance_mix"])))
	var ordered_clarity := (
			float(glacier["contrast_retention"]) < float(left["contrast_retention"])
			and float(glacier["contrast_retention"]) < float(right["contrast_retention"])
			and float(left["contrast_retention"]) < float(shore["contrast_retention"])
			and float(right["contrast_retention"]) < float(shore["contrast_retention"])
			and is_equal_approx(
					float(shore_secondary["contrast_retention"]),
					float(shore["contrast_retention"])))
	var alpha_preserved := true
	var useful_ranges := true
	var color_preserved := true
	var balanced_luma := true
	for role: String in metrics:
		var item := metrics[role] as Dictionary
		alpha_preserved = alpha_preserved and (
				int(item["source_opaque_pixels"]) == int(item["graded_opaque_pixels"]))
		useful_ranges = useful_ranges and float(item["graded_luma_range"]) >= 0.055
		color_preserved = color_preserved and (
				float(item["graded_saturation"])
						>= float(item["source_saturation"]) * 0.84
				and float(item["graded_saturation"])
						<= float(item["source_saturation"]) + 0.035)
		balanced_luma = balanced_luma and (
				float(item["graded_luma"]) >= float(item["source_luma"]) * 0.66
				and float(item["graded_luma"])
						<= float(item["source_luma"]) * 0.97)
	return {
		"passed": (
				ordered_depth and ordered_clarity and alpha_preserved
				and useful_ranges and color_preserved and balanced_luma),
		"ordered_depth": ordered_depth,
		"ordered_clarity": ordered_clarity,
		"alpha_preserved": alpha_preserved,
		"useful_ranges": useful_ranges,
		"color_preserved": color_preserved,
		"balanced_luma": balanced_luma,
		"materials": metrics,
	}


func _measure_layer_grade(layer: TextureRect, material: ShaderMaterial) -> Dictionary:
	var image := layer.texture.get_image()
	var source_saturation_total := 0.0
	var graded_saturation_total := 0.0
	var source_luma_total := 0.0
	var graded_luma_total := 0.0
	var source_count := 0
	var graded_count := 0
	var graded_min_luma := 1.0
	var graded_max_luma := 0.0
	var graded_highlight_total := 0.0
	var highlight_count := 0
	for y: int in image.get_height():
		var uv_y := (float(y) + 0.5) / float(image.get_height())
		for x: int in image.get_width():
			var source := image.get_pixel(x, y)
			if source.a < 0.03:
				continue
			source_count += 1
			source_saturation_total += _color_saturation(source)
			source_luma_total += _color_luminance(source)
			var graded := _grade_source_color(source, uv_y, material)
			if graded.a < 0.03:
				continue
			graded_count += 1
			graded_saturation_total += _color_saturation(graded)
			var graded_luma := _color_luminance(graded)
			graded_luma_total += graded_luma
			graded_min_luma = min(graded_min_luma, graded_luma)
			graded_max_luma = max(graded_max_luma, graded_luma)
			if _color_luminance(source) >= 0.58:
				highlight_count += 1
				graded_highlight_total += graded_luma
	return {
		"valid": true,
		"distance_mix": float(material.get_shader_parameter("distance_mix")),
		"contrast_retention": float(material.get_shader_parameter("contrast_retention")),
		"source_opaque_pixels": source_count,
		"graded_opaque_pixels": graded_count,
		"source_saturation": source_saturation_total / maxf(float(source_count), 1.0),
		"graded_saturation": graded_saturation_total / maxf(float(graded_count), 1.0),
		"source_luma": source_luma_total / maxf(float(source_count), 1.0),
		"graded_luma": graded_luma_total / maxf(float(graded_count), 1.0),
		"graded_luma_range": graded_max_luma - graded_min_luma,
		"graded_highlight_luma": (
				graded_highlight_total / maxf(float(highlight_count), 1.0)),
	}


func _grade_source_color(
		source: Color, uv_y: float, material: ShaderMaterial) -> Color:
	var source_luma := _color_luminance(source)
	var saturation := float(material.get_shader_parameter("saturation_retention"))
	var contrast := float(material.get_shader_parameter("contrast_retention"))
	var brightness := float(material.get_shader_parameter("brightness"))
	var color := Color(source_luma, source_luma, source_luma).lerp(source, saturation)
	color = Color(
			source_luma + (color.r - source_luma) * contrast,
			source_luma + (color.g - source_luma) * contrast,
			source_luma + (color.b - source_luma) * contrast)
	color = Color(color.r * brightness, color.g * brightness, color.b * brightness)
	var upper_air := 1.0 - smoothstep(0.08, 0.92, uv_y)
	var upper_bias := float(material.get_shader_parameter("upper_air_bias"))
	var local_air := float(material.get_shader_parameter("distance_mix")) * lerpf(
			1.0, upper_air, upper_bias)
	var visible_luma := clampf(
			source_luma * brightness
					+ float(material.get_shader_parameter("visibility_lift")) * local_air,
			0.0,
			0.92)
	var sky_shifted := color.lerp(
			material.get_shader_parameter("sky_tint") as Color, local_air)
	color = sky_shifted * (visible_luma / maxf(_color_luminance(sky_shifted), 0.001))
	var highlight_receiver := smoothstep(0.22, 0.78, source_luma)
	var aurora_receiver := upper_air * lerpf(0.35, 1.0, highlight_receiver)
	var aurora_shifted := color.lerp(
			material.get_shader_parameter("aurora_tint") as Color,
			aurora_receiver * float(material.get_shader_parameter("aurora_bounce")))
	color = aurora_shifted * (
			visible_luma / maxf(_color_luminance(aurora_shifted), 0.001))
	var steps := float(material.get_shader_parameter("palette_steps"))
	return Color(
			floor(clampf(color.r, 0.0, 1.0) * steps + 0.5) / steps,
			floor(clampf(color.g, 0.0, 1.0) * steps + 0.5) / steps,
			floor(clampf(color.b, 0.0, 1.0) * steps + 0.5) / steps,
			source.a)


func _probe_foreground_grade(
		center: TextureRect,
		left: TextureRect,
		right: TextureRect) -> Dictionary:
	if center == null or left == null or right == null:
		return {"passed": false, "reason": "missing foreground layer"}
	var layers := {"center": center, "left": left, "right": right}
	var metrics := {}
	var materials_valid := true
	var alpha_preserved := true
	var balanced_luma := true
	var color_preserved := true
	var snow_readable := true
	var parallax_unified := true
	for role: String in layers:
		var layer := layers[role] as TextureRect
		var material := layer.material as ShaderMaterial
		if (material == null or material.shader == null
				or material.shader.resource_path != FOREGROUND_GRADE_SHADER_PATH):
			materials_valid = false
			metrics[role] = {"valid": false}
			continue
		var item := _measure_foreground_grade(layer, material)
		metrics[role] = item
		alpha_preserved = alpha_preserved and (
				int(item["source_opaque_pixels"])
				== int(item["graded_opaque_pixels"]))
		balanced_luma = balanced_luma and (
				float(item["graded_luma"]) <= float(item["source_luma"]) * 0.96
				and float(item["graded_luma"])
						>= float(item["source_luma"]) * 0.80)
		color_preserved = color_preserved and (
				float(item["graded_saturation"])
						>= float(item["source_saturation"]) * 0.76)
		snow_readable = snow_readable and (
				float(item["graded_snow_contrast"]) >= 0.09)
		parallax_unified = parallax_unified and (
				is_equal_approx(float(layer.get_meta("parallax_factor")), 1.18))
	var ordered := center.get_index() < left.get_index() \
			and center.get_index() < right.get_index()
	return {
		"passed": (
				materials_valid and alpha_preserved and balanced_luma
				and color_preserved and snow_readable
				and parallax_unified and ordered),
		"materials_valid": materials_valid,
		"alpha_preserved": alpha_preserved,
		"balanced_luma": balanced_luma,
		"color_preserved": color_preserved,
		"snow_readable": snow_readable,
		"parallax_unified": parallax_unified,
		"ordered": ordered,
		"layers": metrics,
	}


func _measure_foreground_grade(
		layer: TextureRect, material: ShaderMaterial) -> Dictionary:
	var image := layer.texture.get_image()
	var source_luma_total := 0.0
	var graded_luma_total := 0.0
	var graded_snow_total := 0.0
	var graded_body_total := 0.0
	var source_saturation_total := 0.0
	var graded_saturation_total := 0.0
	var source_count := 0
	var graded_count := 0
	var snow_count := 0
	var body_count := 0
	for y: int in image.get_height():
		var uv_y := (float(y) + 0.5) / float(image.get_height())
		for x: int in image.get_width():
			var source := image.get_pixel(x, y)
			if source.a < 0.03:
				continue
			var source_up := image.get_pixel(x, maxi(y - 1, 0))
			var source_luma := _color_luminance(source)
			var graded := _grade_foreground_color(
					source, source_up, uv_y, material)
			source_count += 1
			source_luma_total += source_luma
			source_saturation_total += _color_saturation(source)
			if graded.a < 0.03:
				continue
			graded_count += 1
			graded_saturation_total += _color_saturation(graded)
			var graded_luma := _color_luminance(graded)
			graded_luma_total += graded_luma
			if source_luma >= 0.58:
				snow_count += 1
				graded_snow_total += graded_luma
			else:
				body_count += 1
				graded_body_total += graded_luma
	var source_mean := source_luma_total / maxf(float(source_count), 1.0)
	var graded_mean := graded_luma_total / maxf(float(graded_count), 1.0)
	var snow_mean := graded_snow_total / maxf(float(snow_count), 1.0)
	var body_mean := graded_body_total / maxf(float(body_count), 1.0)
	return {
		"valid": true,
		"source_opaque_pixels": source_count,
		"graded_opaque_pixels": graded_count,
		"source_luma": snappedf(source_mean, 0.001),
		"graded_luma": snappedf(graded_mean, 0.001),
		"luma_ratio": snappedf(graded_mean / maxf(source_mean, 0.001), 0.001),
		"source_saturation": snappedf(
				source_saturation_total / maxf(float(source_count), 1.0), 0.001),
		"graded_saturation": snappedf(
				graded_saturation_total / maxf(float(graded_count), 1.0), 0.001),
		"graded_snow_luma": snappedf(snow_mean, 0.001),
		"graded_body_luma": snappedf(body_mean, 0.001),
		"graded_snow_contrast": snappedf(snow_mean - body_mean, 0.001),
	}


func _probe_joint_balance(
		far_grade: Dictionary, foreground_grade: Dictionary) -> Dictionary:
	if not bool(far_grade.get("passed", false)) \
			or not bool(foreground_grade.get("passed", false)):
		return {"passed": false, "reason": "individual grade failed"}
	var far_materials := far_grade["materials"] as Dictionary
	var foreground_layers := foreground_grade["layers"] as Dictionary
	var far_highlight_total := 0.0
	var far_highlight_count := 0
	for role: String in far_materials:
		var value := float((far_materials[role] as Dictionary)[
				"graded_highlight_luma"])
		if value <= 0.0:
			continue
		far_highlight_total += value
		far_highlight_count += 1
	var foreground_snow_total := 0.0
	var foreground_snow_count := 0
	for role: String in foreground_layers:
		var value := float((foreground_layers[role] as Dictionary)[
				"graded_snow_luma"])
		if value <= 0.0:
			continue
		foreground_snow_total += value
		foreground_snow_count += 1
	var far_highlight_mean := far_highlight_total / maxf(
			float(far_highlight_count), 1.0)
	var foreground_snow_mean := foreground_snow_total / maxf(
			float(foreground_snow_count), 1.0)
	var highlight_gap := foreground_snow_mean - far_highlight_mean
	return {
		"passed": (
				far_highlight_count >= 3 and foreground_snow_count == 3
				and highlight_gap >= 0.02 and highlight_gap <= 0.18),
		"far_highlight_luma": snappedf(far_highlight_mean, 0.001),
		"foreground_snow_luma": snappedf(foreground_snow_mean, 0.001),
		"highlight_gap": snappedf(highlight_gap, 0.001),
	}


func _grade_foreground_color(
		source: Color,
		source_up: Color,
		uv_y: float,
		material: ShaderMaterial) -> Color:
	var luma := _color_luminance(source)
	var up_luma := _color_luminance(source_up)
	var saturation := float(material.get_shader_parameter("saturation_retention"))
	var brightness := float(material.get_shader_parameter("brightness"))
	var retained := Color(luma, luma, luma).lerp(source, saturation) * brightness
	var snow_threshold := float(material.get_shader_parameter("snow_threshold"))
	var snow_softness := float(material.get_shader_parameter("snow_softness"))
	var snow_mask := smoothstep(
			snow_threshold - snow_softness,
			snow_threshold + snow_softness,
			luma)
	var middle_mix := smoothstep(0.08, 0.52, luma)
	var shadow := material.get_shader_parameter("shadow_palette") as Color
	var middle := material.get_shader_parameter("middle_palette") as Color
	var snow := material.get_shader_parameter("snow_palette") as Color
	var mapped := shadow.lerp(middle, middle_mix).lerp(snow, snow_mask)
	var color := retained.lerp(
			mapped, float(material.get_shader_parameter("palette_strength")))
	var retained_snow := _color_component_max(color, source * brightness)
	color = color.lerp(
			retained_snow,
			snow_mask * float(material.get_shader_parameter("snow_retention")) * 0.34)
	var lower_depth := smoothstep(0.42, 1.0, uv_y) \
			* float(material.get_shader_parameter("lower_depth_strength"))
	color *= 1.0 - lower_depth * (1.0 - snow_mask * 0.48)
	var top_silhouette := source.a * (1.0 - _step(0.03, source_up.a))
	var upward_relief := clampf((luma - up_luma) * 3.0, 0.0, 1.0)
	var upper_exposure := 1.0 - smoothstep(0.32, 0.82, uv_y)
	var aurora_mask := snow_mask * upper_exposure \
			* clampf(top_silhouette + upward_relief * 0.42, 0.0, 1.0)
	var aurora := material.get_shader_parameter("aurora_tint") as Color
	color = color.lerp(
			_color_component_max(color, aurora),
			aurora_mask * float(material.get_shader_parameter("aurora_response")))
	var steps := float(material.get_shader_parameter("palette_steps"))
	return Color(
			floor(clampf(color.r, 0.0, 1.0) * steps + 0.5) / steps,
			floor(clampf(color.g, 0.0, 1.0) * steps + 0.5) / steps,
			floor(clampf(color.b, 0.0, 1.0) * steps + 0.5) / steps,
			source.a)


func _color_component_max(first: Color, second: Color) -> Color:
	return Color(
			maxf(first.r, second.r),
			maxf(first.g, second.g),
			maxf(first.b, second.b),
			maxf(first.a, second.a))


func _step(edge: float, value: float) -> float:
	return 0.0 if value < edge else 1.0


func _color_luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _color_saturation(color: Color) -> float:
	var maximum := maxf(color.r, maxf(color.g, color.b))
	var minimum := minf(color.r, minf(color.g, color.b))
	return (maximum - minimum) / maxf(maximum, 0.001)


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
