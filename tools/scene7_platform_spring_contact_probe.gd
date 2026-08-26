extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const SHADER_PATH := \
		"res://assets/shaders/canvas_env_scene7_platform_spring_contact.gdshader"
const FIRST_LINE_ID := -3
const LAST_LINE_ID_EXCLUSIVE := 28
const SAMPLE_CYCLES := 3


func _initialize() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	var contact := stage.get_node("PlatformSpringContact") as ColorRect
	var front_water := stage.get_node("FrontWater") as ColorRect
	var material := contact.material as ShaderMaterial
	var front_material := front_water.material as ShaderMaterial
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	var material_contract := _material_contract(material, front_material)
	var architecture_contract := (
		source.contains("authored_line_width")
		and source.contains("authored_line_start")
		and source.contains("single_line_mask")
		and source.contains("maximum_edge_cut")
		and source.contains("contact_event_state")
		and source.contains("floor(TIME * anim_fps) / anim_fps")
		and source.contains("line_width_px - edge_cut_px")
		and not source.contains("segment_width_px")
		and not source.contains("segment_density")
		and not source.contains("cluster_layout"))
	var metrics := _sample_lines(material)
	var line_geometry_contract := (
		int(metrics["width_tier_mask"]) == 15
		and int(metrics["minimum_authored_width_px"]) == 24
		and int(metrics["maximum_authored_width_px"]) == 54
		and int(metrics["minimum_gap_px"]) >= 16
		and int(metrics["merged_neighbor_violations"]) == 0
		and int(metrics["minimum_visible_ratio_percent"]) >= 50)
	var motion_contract := (
		float(metrics["maximum_edge_move_per_tick"]) <= 1.0
		and float(metrics["minimum_event_duration_sec"]) >= 4.5
		and float(metrics["maximum_event_duration_sec"]) <= 6.25
		and int(metrics["cycle_end_discontinuities"]) == 0
		and int(metrics["event_ticks"]) > 0
		and int(metrics["unique_cycle_signatures"]) >= 2)
	var passed := (
		material_contract
		and architecture_contract
		and line_geometry_contract
		and motion_contract)
	print(
		"SCENE7_PLATFORM_SPRING_CONTACT_WHOLE_LINE_MOTION: ",
		"PASS" if passed else "FAIL",
		" material_contract=", material_contract,
		" architecture_contract=", architecture_contract,
		" line_geometry_contract=", line_geometry_contract,
		" motion_contract=", motion_contract,
		" metrics=", metrics)
	stage.free()
	quit(0 if passed else 1)


func _material_contract(
		material: ShaderMaterial,
		front_material: ShaderMaterial) -> bool:
	if material == null or front_material == null:
		return false
	return (
		material.shader.resource_path == SHADER_PATH
		and float(material.get_shader_parameter("line_cell_width_px")) == 78.0
		and float(material.get_shader_parameter("line_presence")) == 0.86
		and float(material.get_shader_parameter("line_margin_px")) == 8.0
		and float(material.get_shader_parameter("contact_thickness_px")) == 5.0
		and float(material.get_shader_parameter("minimum_thickness_px")) == 3.0
		and float(material.get_shader_parameter("anim_fps")) == 8.0
		and float(material.get_shader_parameter("spring_period_sec")) == 7.6
		and float(material.get_shader_parameter("active_line_ratio")) == 0.64
		and material.get_shader_parameter("surface_color")
				== front_material.get_shader_parameter("surface_color")
		and material.get_shader_parameter("ripple_color")
				== front_material.get_shader_parameter("ripple_color")
		and material.get_shader_parameter("spring_glow_color")
				== front_material.get_shader_parameter("spring_glow_color"))


func _sample_lines(material: ShaderMaterial) -> Dictionary:
	var cell_width := int(material.get_shader_parameter("line_cell_width_px"))
	var margin := int(material.get_shader_parameter("line_margin_px"))
	var fps := float(material.get_shader_parameter("anim_fps"))
	var period := float(material.get_shader_parameter("spring_period_sec"))
	var ticks_per_cycle := floori(period * fps)
	var width_tier_mask := 0
	var minimum_authored_width := 999
	var maximum_authored_width := 0
	var minimum_gap := 999
	var merged_neighbor_violations := 0
	var previous_end := -999999
	for line_id: int in range(FIRST_LINE_ID, LAST_LINE_ID_EXCLUSIVE):
		var width := _authored_width(line_id)
		var start := _authored_start(line_id, width, cell_width, margin)
		var global_start := line_id * cell_width + start
		var global_end := global_start + width
		var gap := global_start - previous_end
		if line_id > FIRST_LINE_ID:
			minimum_gap = mini(minimum_gap, gap)
			merged_neighbor_violations += 1 if gap <= 0 else 0
		previous_end = global_end
		minimum_authored_width = mini(minimum_authored_width, width)
		maximum_authored_width = maxi(maximum_authored_width, width)
		width_tier_mask |= 1 << floori(float(width - 24) / 10.0)

	var previous_cuts: Dictionary[int, int] = {}
	var maximum_edge_move_per_tick := 0.0
	var minimum_visible_ratio_percent := 100
	var minimum_event_duration_sec := INF
	var maximum_event_duration_sec := 0.0
	var cycle_end_discontinuities := 0
	var event_ticks := 0
	var cycle_signatures: Array[String] = []
	for cycle_index: int in SAMPLE_CYCLES:
		var active_lines: Dictionary[int, bool] = {}
		for tick: int in ticks_per_cycle:
			var time_sec := float(cycle_index) * period + float(tick) / fps
			for line_id: int in range(FIRST_LINE_ID, LAST_LINE_ID_EXCLUSIVE):
				var width := _authored_width(line_id)
				var state := _event_state(line_id, width, time_sec, material)
				var edge_cut := int(state["edge_cut_px"])
				var visible_width := width - edge_cut * 2
				minimum_visible_ratio_percent = mini(
						minimum_visible_ratio_percent,
						floori(float(visible_width) * 100.0 / float(width)))
				if previous_cuts.has(line_id):
					maximum_edge_move_per_tick = maxf(
							maximum_edge_move_per_tick,
							absf(float(edge_cut - previous_cuts[line_id])))
				previous_cuts[line_id] = edge_cut
				if bool(state["event_active"]):
					event_ticks += 1
					active_lines[line_id] = true
				if bool(state["active_cycle"]):
					var event_duration := float(state["event_frames"]) / fps
					minimum_event_duration_sec = minf(
							minimum_event_duration_sec, event_duration)
					maximum_event_duration_sec = maxf(
							maximum_event_duration_sec, event_duration)
				if tick >= ticks_per_cycle - 2 \
						and (bool(state["event_active"]) or edge_cut != 0):
					cycle_end_discontinuities += 1
		var signature: Array = active_lines.keys()
		signature.sort()
		cycle_signatures.append(str(signature))
	var unique_signatures: Dictionary[String, bool] = {}
	for signature: String in cycle_signatures:
		unique_signatures[signature] = true
	return {
		"width_tier_mask": width_tier_mask,
		"minimum_authored_width_px": minimum_authored_width,
		"maximum_authored_width_px": maximum_authored_width,
		"minimum_gap_px": minimum_gap,
		"merged_neighbor_violations": merged_neighbor_violations,
		"minimum_visible_ratio_percent": minimum_visible_ratio_percent,
		"maximum_edge_move_per_tick": maximum_edge_move_per_tick,
		"minimum_event_duration_sec": snappedf(minimum_event_duration_sec, 0.001),
		"maximum_event_duration_sec": snappedf(maximum_event_duration_sec, 0.001),
		"cycle_end_discontinuities": cycle_end_discontinuities,
		"event_ticks": event_ticks,
		"unique_cycle_signatures": unique_signatures.size(),
		"cycle_signatures": cycle_signatures,
	}


func _authored_width(line_id: int) -> int:
	return 24 + floori(_stable_hash(float(line_id) * 5.71 + 3.4) * 4.0) * 10


func _authored_start(
		line_id: int,
		line_width: int,
		cell_width: int,
		margin: int) -> int:
	var free_space := maxi(0, cell_width - margin * 2 - line_width)
	return margin + floori(
			_stable_hash(float(line_id) * 9.13 + 7.2)
			* float(free_space + 1))


func _event_state(
		line_id: int,
		line_width: int,
		time_sec: float,
		material: ShaderMaterial) -> Dictionary:
	var fps := float(material.get_shader_parameter("anim_fps"))
	var period := float(material.get_shader_parameter("spring_period_sec"))
	var active_ratio := float(material.get_shader_parameter("active_line_ratio"))
	var pixel_time := floorf(time_sec * fps) / fps
	var cycle_id := floori(pixel_time / period)
	var cycle_frame := floori(fposmod(pixel_time, period) * fps)
	var participation := _stable_hash(
			float(line_id) * 3.17 + float(cycle_id) * 47.11 + 5.3)
	var active_cycle := participation >= 1.0 - active_ratio
	var onset_frames := 1 + floori(_stable_hash(
			float(line_id) * 11.7 + float(cycle_id) * 7.9 + 2.1) * 4.0)
	var maximum_edge_cut := floori(float(line_width) * 0.25)
	var retract_frames := maxi(
			14,
			maximum_edge_cut + 2 + floori(_stable_hash(
			float(line_id) * 5.9 + float(cycle_id) * 13.1 + 8.4) * 5.0))
	var hold_frames := 6 + floori(_stable_hash(
			float(line_id) * 17.3 + float(cycle_id) * 3.7 + 1.6) * 5.0)
	var recover_frames := maxi(
			17,
			maximum_edge_cut + 4 + floori(_stable_hash(
			float(line_id) * 23.9 + float(cycle_id) * 5.1 + 9.2) * 6.0))
	var local_frame := cycle_frame - onset_frames
	var event_frames := retract_frames + hold_frames + recover_frames
	var event_active := active_cycle and local_frame >= 0 and local_frame < event_frames
	var edge_cut := 0
	if event_active:
		if local_frame < retract_frames:
			edge_cut = floori(
					float(local_frame * (maximum_edge_cut + 1))
					/ float(retract_frames))
		elif local_frame < retract_frames + hold_frames:
			edge_cut = maximum_edge_cut
		else:
			var recovery_frame := local_frame - retract_frames - hold_frames
			edge_cut = maximum_edge_cut - floori(
					float(recovery_frame * (maximum_edge_cut + 1))
					/ float(recover_frames))
		edge_cut = clampi(edge_cut, 0, maximum_edge_cut)
	return {
		"edge_cut_px": edge_cut,
		"event_active": event_active,
		"active_cycle": active_cycle,
		"event_frames": event_frames,
	}


func _stable_hash(value: float) -> float:
	return fposmod(sin(value * 12.9898) * 43758.5453, 1.0)
