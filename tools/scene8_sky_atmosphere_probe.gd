extends SceneTree

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")
const SKY_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_aurora_sky.gdshader")
const STAR_SHADER_PATH := "res://assets/shaders/canvas_env_stars.gdshader"


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var stage := SCENE8.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	var sky := stage.get_node_or_null("Sky") as ColorRect
	var stars := stage.get_node_or_null("Stars") as ColorRect
	var aurora := stage.get_node_or_null("PixelAurora") as TextureRect
	if sky == null or stars == null or aurora == null:
		print("SCENE8_SKY_ATMOSPHERE_PROBE: FAIL reason=missing sky chain")
		quit(1)
		return
	var sky_material := sky.material as ShaderMaterial
	var star_material := stars.material as ShaderMaterial
	var aurora_material := aurora.material as ShaderMaterial
	if sky_material == null or star_material == null or aurora_material == null:
		print("SCENE8_SKY_ATMOSPHERE_PROBE: FAIL reason=missing local material")
		quit(1)
		return

	var band_metrics := {
		"zenith": _sample_band(sky_material, 0.08, 0.0, true),
		"upper_echo": _sample_band(sky_material, 0.24, 0.0, true),
		"airglow": _sample_band(sky_material, 0.39, 0.0, true),
		"horizon": _sample_band(sky_material, 0.72, 0.0, true),
	}
	var airglow_base := _sample_band(sky_material, 0.39, 0.0, false)
	var echo_base := _sample_band(sky_material, 0.24, 0.0, false)
	var airglow_gain := float(band_metrics["airglow"]["average"]) \
			- float(airglow_base["average"])
	var echo_gain := float(band_metrics["upper_echo"]["average"]) \
			- float(echo_base["average"])
	var temporal_delta := _temporal_delta(sky_material, 0.39, 0.0, 60.0)
	var source := FileAccess.get_file_as_string(SKY_SHADER_PATH)
	var star_source := FileAccess.get_file_as_string(STAR_SHADER_PATH)
	var star_metrics := _measure_star_distribution(star_material, 161.746)
	var star_seed_sweep := _measure_star_seed_stability(star_material)
	var layer_order := (
			sky.get_index() < stars.get_index()
			and stars.get_index() < aurora.get_index()
			and aurora.get_index() < stage.get_node("AuroraReflectionGrab").get_index())
	var zenith_luma := float(band_metrics["zenith"]["average"])
	var airglow_luma := float(band_metrics["airglow"]["average"])
	var horizon_luma := float(band_metrics["horizon"]["average"])
	var airglow_range := float(band_metrics["airglow"]["maximum"]) \
			- float(band_metrics["airglow"]["minimum"])
	var clarity_chroma := {
		"zenith": _sample_chroma_band(sky_material, 0.08, 0.0),
		"upper": _sample_chroma_band(sky_material, 0.24, 0.0),
		"horizon": _sample_chroma_band(sky_material, 0.72, 0.0),
	}
	var mountain_green := _sample_color_band(sky_material, 0.50, 0.0, true)
	var mountain_without_green := _sample_color_band(sky_material, 0.50, 0.0, false)
	var mountain_green_delta := mountain_green - mountain_without_green
	var passed := (
			sky_material.resource_local_to_scene
			and sky_material.shader.resource_path == SKY_SHADER_PATH
			and zenith_luma >= 0.035 and zenith_luma <= 0.075
			and airglow_luma >= 0.08 and airglow_luma <= 0.16
			and horizon_luma >= 0.125 and horizon_luma <= 0.20
			and zenith_luma < airglow_luma and airglow_luma < horizon_luma
			and airglow_gain >= 0.008 and airglow_gain <= 0.045
			and echo_gain >= 0.001 and echo_gain <= 0.025
			and airglow_range >= 0.0015 and airglow_range <= 0.04
			and temporal_delta >= 0.0001 and temporal_delta <= 0.02
			and float(clarity_chroma["zenith"]) >= 0.08
			and float(clarity_chroma["upper"]) >= 0.11
			and float(clarity_chroma["horizon"]) >= 0.16
			and float(sky_material.get_shader_parameter("texture_strength")) <= 0.025
			and float(sky_material.get_shader_parameter("dither_amount")) <= 0.003
			and star_material.resource_local_to_scene
			and star_material.shader.resource_path == STAR_SHADER_PATH
			and bool(star_metrics["passed"])
			and bool(star_seed_sweep["passed"])
			and float(star_material.get_shader_parameter("pixel_grid")) >= 760.0
			and float(star_material.get_shader_parameter("twinkle_depth")) <= 0.16
			and mountain_green_delta.y >= 0.008
			and mountain_green_delta.y > mountain_green_delta.x
			and mountain_green_delta.y > mountain_green_delta.z
			and mountain_green_delta.length() <= 0.055
			and float(aurora_material.get_shader_parameter("far_halo_strength")) >= 0.07
			and float(aurora_material.get_shader_parameter(
					"far_halo_radius_pixels")) >= 5.0
			and source.contains("layered_airglow")
			and source.contains("upper_echo")
			and source.contains("broad_noise")
			and source.contains("ridge_noise")
			and source.contains("horizon_green_veil")
			and source.contains("veil_bend")
			and star_source.contains("star_contrib")
			and star_source.contains("pixel_grid")
			and layer_order)
	print(
			"SCENE8_SKY_ATMOSPHERE_PROBE: ", "PASS" if passed else "FAIL",
			" bands=", band_metrics,
			" airglow_gain=", snappedf(airglow_gain, 0.0001),
			" echo_gain=", snappedf(echo_gain, 0.0001),
			" airglow_horizontal_range=", snappedf(airglow_range, 0.0001),
			" clarity_chroma=", clarity_chroma,
			" mountain_green=", mountain_green,
			" mountain_green_delta=", mountain_green_delta,
			" temporal_delta_60s=", snappedf(temporal_delta, 0.0001),
			" stars=", star_metrics,
			" star_seed_sweep=", star_seed_sweep,
			" far_halo=", Vector2(
					float(aurora_material.get_shader_parameter("far_halo_strength")),
					float(aurora_material.get_shader_parameter("far_halo_radius_pixels"))),
			" layer_order=", layer_order)
	stage.queue_free()
	quit(0 if passed else 1)


func _sample_band(
		material: ShaderMaterial,
		y: float,
		time_sec: float,
		include_airglow: bool) -> Dictionary:
	var minimum := INF
	var maximum := -INF
	var total := 0.0
	const SAMPLE_COUNT := 96
	for sample_index: int in SAMPLE_COUNT:
		var x := (float(sample_index) + 0.5) / float(SAMPLE_COUNT)
		var color := _sample_sky(material, Vector2(x, y), time_sec, include_airglow)
		var luma := _luma(color)
		minimum = minf(minimum, luma)
		maximum = maxf(maximum, luma)
		total += luma
	return {
		"average": snappedf(total / float(SAMPLE_COUNT), 0.0001),
		"minimum": snappedf(minimum, 0.0001),
		"maximum": snappedf(maximum, 0.0001),
	}


func _temporal_delta(
		material: ShaderMaterial,
		y: float,
		start_time: float,
		end_time: float) -> float:
	var total := 0.0
	const SAMPLE_COUNT := 96
	for sample_index: int in SAMPLE_COUNT:
		var x := (float(sample_index) + 0.5) / float(SAMPLE_COUNT)
		var start_color := _sample_sky(material, Vector2(x, y), start_time, true)
		var end_color := _sample_sky(material, Vector2(x, y), end_time, true)
		total += (end_color - start_color).length()
	return total / float(SAMPLE_COUNT)


func _sample_chroma_band(
		material: ShaderMaterial,
		y: float,
		time_sec: float) -> float:
	var total := 0.0
	const SAMPLE_COUNT := 96
	for sample_index: int in SAMPLE_COUNT:
		var x := (float(sample_index) + 0.5) / float(SAMPLE_COUNT)
		var color := _sample_sky(material, Vector2(x, y), time_sec, true)
		total += maxf(maxf(color.x, color.y), color.z) \
				- minf(minf(color.x, color.y), color.z)
	return snappedf(total / float(SAMPLE_COUNT), 0.0001)


func _sample_color_band(
		material: ShaderMaterial,
		y: float,
		time_sec: float,
		include_horizon_green: bool) -> Vector3:
	var total := Vector3.ZERO
	const SAMPLE_COUNT := 96
	for sample_index: int in SAMPLE_COUNT:
		var x := (float(sample_index) + 0.5) / float(SAMPLE_COUNT)
		total += _sample_sky(
				material,
				Vector2(x, y),
				time_sec,
				true,
				include_horizon_green)
	return total / float(SAMPLE_COUNT)


func _measure_star_distribution(
		material: ShaderMaterial,
		seed_override: float = -1.0) -> Dictionary:
	var grid := material.get_shader_parameter("grid") as Vector2
	var seed_value := seed_override if seed_override >= 0.0 else float(
			material.get_shader_parameter("seed"))
	var coverage := float(material.get_shader_parameter("coverage"))
	var band_scale := float(material.get_shader_parameter("band_scale"))
	var gap_threshold := float(material.get_shader_parameter("gap_threshold"))
	var band_soft := float(material.get_shader_parameter("band_soft"))
	var sky_bottom := float(material.get_shader_parameter("sky_bottom"))
	var top_concentration := float(material.get_shader_parameter("top_concentration"))
	var bright_ratio := float(material.get_shader_parameter("bright_ratio"))
	const BIN_COLUMNS := 12
	const BIN_ROWS := 4
	var bins: Array[int] = []
	bins.resize(BIN_COLUMNS * BIN_ROWS)
	bins.fill(0)
	var visible_stars := 0
	var bright_stars := 0
	var sky_candidates := 0
	for cell_y: int in int(grid.y):
		for cell_x: int in int(grid.x):
			var source_cell := Vector2(cell_x, cell_y)
			var random_offset := _star_hash22(
					source_cell + Vector2(seed_value + 7.7, seed_value + 7.7))
			var star_uv := (source_cell + random_offset) / grid
			if star_uv.y > sky_bottom:
				continue
			sky_candidates += 1
			var density := clampf(
					_star_fbm(star_uv * band_scale
							+ Vector2(seed_value * 0.13, seed_value * 0.07)) * 1.3,
					0.0,
					1.0)
			var band := smoothstep(gap_threshold, gap_threshold + band_soft, density)
			var vertical_weight := lerpf(
					top_concentration,
					1.0,
					smoothstep(sky_bottom, 0.0, star_uv.y))
			var probability := coverage * band * vertical_weight
			var present := _star_hash21(
					source_cell + Vector2(seed_value + 1.3, seed_value + 1.3)) \
					>= 1.0 - probability
			if not present:
				continue
			visible_stars += 1
			var tier_random := _star_hash21(source_cell
					+ Vector2(seed_value + 9.1, seed_value + 9.1))
			bright_stars += 1 if tier_random >= 1.0 - bright_ratio else 0
			var bin_x := clampi(int(floor(star_uv.x * BIN_COLUMNS)), 0, BIN_COLUMNS - 1)
			var normalized_y := star_uv.y / maxf(sky_bottom, 0.001)
			var bin_y := clampi(int(floor(normalized_y * BIN_ROWS)), 0, BIN_ROWS - 1)
			bins[bin_y * BIN_COLUMNS + bin_x] += 1
	var empty_bins := 0
	var fullest_bin := 0
	for count: int in bins:
		empty_bins += 1 if count == 0 else 0
		fullest_bin = maxi(fullest_bin, count)
	var passed := (
			visible_stars >= 12 and visible_stars <= 180
			and empty_bins >= 16
			and fullest_bin >= 2
			and bright_stars <= 10)
	return {
		"passed": passed,
		"visible": visible_stars,
		"sky_candidates": sky_candidates,
		"empty_bins": empty_bins,
		"fullest_bin": fullest_bin,
		"bright_stars": bright_stars,
	}


func _measure_star_seed_stability(material: ShaderMaterial) -> Dictionary:
	var minimum_visible := 1000000
	var maximum_visible := 0
	var minimum_empty_bins := 1000000
	var maximum_bright_count := 0
	var samples: Array[int] = []
	for seed_value: float in [0.0, 73.2, 191.7, 348.71, 527.4, 777.7, 999.0]:
		var metrics := _measure_star_distribution(material, seed_value)
		var visible := int(metrics["visible"])
		minimum_visible = mini(minimum_visible, visible)
		maximum_visible = maxi(maximum_visible, visible)
		minimum_empty_bins = mini(minimum_empty_bins, int(metrics["empty_bins"]))
		maximum_bright_count = maxi(
				maximum_bright_count,
				int(metrics["bright_stars"]))
		samples.append(visible)
	var stable := (
			minimum_visible >= 10
			and maximum_visible <= 200
			and maximum_visible - minimum_visible <= 100
			and minimum_empty_bins >= 10
			and maximum_bright_count <= 12)
	return {
		"passed": stable,
		"visible_range": Vector2i(minimum_visible, maximum_visible),
		"minimum_empty_bins": minimum_empty_bins,
		"maximum_bright_count": maximum_bright_count,
		"samples": samples,
	}


func _sample_sky(
		material: ShaderMaterial,
		uv: Vector2,
		time_sec: float,
		include_airglow: bool,
		include_horizon_green: bool = true) -> Vector3:
	var pixel_grid := material.get_shader_parameter("pixel_grid") as Vector2
	var pixel_uv := (Vector2(floor(uv.x * pixel_grid.x), floor(uv.y * pixel_grid.y))
			+ Vector2(0.5, 0.5)) / pixel_grid
	var y := pixel_uv.y
	var zenith := _color3(material.get_shader_parameter("zenith_color") as Color)
	var upper := _color3(material.get_shader_parameter("upper_color") as Color)
	var horizon := _color3(material.get_shader_parameter("horizon_color") as Color)
	var upper_transition := float(material.get_shader_parameter("upper_transition"))
	var horizon_transition := float(material.get_shader_parameter("horizon_transition"))
	var upper_mix := smoothstep(0.03, upper_transition, pow(y, 0.90))
	var horizon_mix := smoothstep(
			horizon_transition - 0.20,
			horizon_transition + 0.18,
			pow(y, 1.08))
	var color := zenith.lerp(upper, upper_mix).lerp(horizon, horizon_mix)
	var drift := float(material.get_shader_parameter("airglow_drift"))
	var slow_time := time_sec * drift
	var broad_noise := _fbm(Vector2(pixel_uv.x * 2.25 + slow_time, y * 1.25 + 1.7))
	var ridge_noise := _value_noise(Vector2(
			pixel_uv.x * 6.1 - slow_time * 0.73,
			6.4 + slow_time * 0.31))
	var irregularity := float(material.get_shader_parameter("airglow_irregularity"))
	var center := float(material.get_shader_parameter("airglow_center")) \
			+ (broad_noise - 0.5) * irregularity \
			+ (ridge_noise - 0.5) * irregularity * 0.32
	var width := float(material.get_shader_parameter("airglow_width"))
	var lower_veil := _bell(y, center, width)
	var upper_echo := _bell(y, center - width * 0.72, width * 0.52)
	var breakup := lerpf(
			0.70,
			1.0,
			_fbm(Vector2(pixel_uv.x * 4.4 + 8.2, y * 7.0 - slow_time * 0.41)))
	var layered_airglow := clampf(
			(lower_veil * 0.74 + upper_echo * 0.26) * breakup, 0.0, 1.0)
	if include_airglow:
		var green_field := smoothstep(
				0.24, 0.82,
				_fbm(Vector2(pixel_uv.x * 1.85 + 2.3, 3.2 + slow_time * 0.22)))
		var violet_field := smoothstep(
				0.38, 0.88,
				_fbm(Vector2(pixel_uv.x * 2.35 + 9.7, 7.1 - slow_time * 0.17)))
		var atmospheric := _color3(
				material.get_shader_parameter("airglow_blue") as Color).lerp(
				_color3(material.get_shader_parameter("airglow_green") as Color),
				green_field * 0.62)
		atmospheric = atmospheric.lerp(
				_color3(material.get_shader_parameter("airglow_violet") as Color),
				violet_field * 0.30)
		color += atmospheric * layered_airglow \
				* float(material.get_shader_parameter("airglow_strength"))
	if include_horizon_green:
		var veil_noise := _fbm(Vector2(
				pixel_uv.x * 3.15 + 4.7 - slow_time * 0.18,
				5.2 + y * 1.7 + slow_time * 0.09))
		var veil_ridge := _value_noise(Vector2(
				pixel_uv.x * 7.4 + 11.3,
				8.6 - slow_time * 0.13))
		var green_irregularity := float(material.get_shader_parameter(
				"horizon_green_irregularity"))
		var veil_bend := ((veil_noise - 0.5) * 0.72
				+ (veil_ridge - 0.5) * 0.28) * green_irregularity
		var green_start := float(material.get_shader_parameter("horizon_green_start"))
		var green_crest := float(material.get_shader_parameter("horizon_green_crest"))
		var green_fade_end := float(material.get_shader_parameter(
				"horizon_green_fade_end"))
		var horizon_rise := smoothstep(
				green_start + veil_bend,
				green_crest + veil_bend * 0.35,
				y)
		var horizon_falloff := 1.0 - smoothstep(
				green_crest + 0.05,
				green_fade_end,
				y)
		var green_veil := horizon_rise * horizon_falloff \
				* lerpf(0.78, 1.0, veil_noise)
		color = color.lerp(
				_color3(material.get_shader_parameter("horizon_green_color") as Color),
				green_veil * float(material.get_shader_parameter(
						"horizon_green_strength")))
	var sky_structure := _fbm(Vector2(
			pixel_uv.x * 2.7 - slow_time * 0.31,
			y * 2.1 + slow_time * 0.12))
	color *= 1.0 + (sky_structure - 0.5) \
			* float(material.get_shader_parameter("texture_strength"))
	return color * float(material.get_shader_parameter("scene_exposure"))


func _hash21(point: Vector2) -> float:
	var value := Vector2(
			_fract(point.x * 123.34),
			_fract(point.y * 345.45))
	value += Vector2.ONE * value.dot(value + Vector2(34.345, 34.345))
	return _fract(value.x * value.y)


func _value_noise(point: Vector2) -> float:
	var cell := Vector2(floor(point.x), floor(point.y))
	var local := Vector2(_fract(point.x), _fract(point.y))
	local = local * local * (Vector2(3.0, 3.0) - 2.0 * local)
	var a := _hash21(cell)
	var b := _hash21(cell + Vector2(1.0, 0.0))
	var c := _hash21(cell + Vector2(0.0, 1.0))
	var d := _hash21(cell + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, local.x), lerpf(c, d, local.x), local.y)


func _fbm(point: Vector2) -> float:
	var sum := 0.0
	var weight := 0.56
	for _octave: int in 3:
		sum += _value_noise(point) * weight
		point = point * 2.03 + Vector2(3.17, 5.83)
		weight *= 0.48
	return sum / 0.962


func _bell(value: float, center: float, width: float) -> float:
	var distance_to_center := (value - center) / maxf(width, 0.001)
	return exp(-distance_to_center * distance_to_center)


func _fract(value: float) -> float:
	return value - floor(value)


func _color3(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)


func _luma(color: Vector3) -> float:
	return color.dot(Vector3(0.2126, 0.7152, 0.0722))


func _star_hash21(point: Vector2) -> float:
	var value := Vector2(
			_fract(point.x * 123.34),
			_fract(point.y * 456.21))
	value += Vector2.ONE * value.dot(value + Vector2(45.32, 45.32))
	return _fract(value.x * value.y)


func _star_hash22(point: Vector2) -> Vector2:
	var first := _star_hash21(point)
	return Vector2(
			_fract(_star_hash21(point + Vector2(first, first))),
			_fract(_star_hash21(point + Vector2(first + 1.7, first + 1.7))))


func _star_value_noise(point: Vector2) -> float:
	var cell := Vector2(floor(point.x), floor(point.y))
	var local := Vector2(_fract(point.x), _fract(point.y))
	local = local * local * (Vector2(3.0, 3.0) - 2.0 * local)
	var a := _star_hash21(cell)
	var b := _star_hash21(cell + Vector2(1.0, 0.0))
	var c := _star_hash21(cell + Vector2(0.0, 1.0))
	var d := _star_hash21(cell + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, local.x), lerpf(c, d, local.x), local.y)


func _star_fbm(point: Vector2) -> float:
	var sum := 0.0
	var weight := 0.6
	for _octave: int in 3:
		sum += _star_value_noise(point) * weight
		point = Vector2(
				0.80 * point.x - 0.60 * point.y,
				0.60 * point.x + 0.80 * point.y) * 2.03 \
				+ Vector2(7.3, 11.7)
		weight *= 0.5
	return sum
