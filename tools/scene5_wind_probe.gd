extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen5.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var far_material := (
			stage.get_node("FarWheat") as Control
			).material as ShaderMaterial
	var mid_far_wheat := stage.get_node("MidFarWheat") as Control
	var mid_far_material := mid_far_wheat.material as ShaderMaterial
	var cover_back := stage.get_node("FarWheatCoverBack") as Control
	var cover_back_material := cover_back.material as ShaderMaterial
	var distant_material := (
			stage.get_node("DistantWheat") as TextureRect
			).material as ShaderMaterial
	var near_material := (
			stage.get_node("NearWheatLeft") as Control
			).material as ShaderMaterial
	var gust_particles := stage.get_node("GustChaff") as GPUParticles2D
	var ambient_particles := stage.get_node("AmbientChaff") as GPUParticles2D
	var wind_field := stage.get_node("WindField")
	var upper_cloud := stage.get_node("UpperCloud") as Control
	var far_wheat := stage.get_node("FarWheat") as Control
	var cloud_moves_left_to_right := upper_cloud.get_child_count() == 1
	for child: Node in upper_cloud.get_children():
		var band := child as ColorRect
		if band == null:
			continue
		var cloud_material := band.material as ShaderMaterial
		if cloud_material == null:
			continue
		var cloud_speed := float(
				cloud_material.get_shader_parameter("flow_speed"))
		if cloud_speed > -0.0025 or cloud_speed < -0.0045:
			cloud_moves_left_to_right = false
		if float(cloud_material.get_shader_parameter("motion_blend")) < 0.99:
			cloud_moves_left_to_right = false
	await _shot(ProbeOutput.path("scene5_wind_ambient_a.png"))
	mid_far_wheat.visible = false
	await _shot(ProbeOutput.path("scene5_mid_depth_without.png"))
	mid_far_wheat.visible = true
	await _shot(ProbeOutput.path("scene5_mid_depth_enabled.png"))
	cover_back.visible = false
	await _shot(ProbeOutput.path("scene5_far_cover_without.png"))
	cover_back.visible = true
	await _shot(ProbeOutput.path("scene5_far_cover_enabled.png"))
	await _wait_real_msec(350)
	await _shot(ProbeOutput.path("scene5_cloud_motion_b.png"))
	await _wait_real_msec(350)
	await _shot(ProbeOutput.path("scene5_cloud_motion_c.png"))
	await _wait_real_msec(1700)
	await _shot(ProbeOutput.path("scene5_wind_ambient_b.png"))
	await get_tree().create_timer(2.4).timeout
	await _shot(ProbeOutput.path("scene5_sun_gate_c.png"))

	var p2_big_direction := float(screen.call(
			"_base_attack_response_direction",
			ActionDef.Action.ATTACK,
			ActionDef.Action.BIG_ATTACK))
	var p1_big_direction := float(screen.call(
			"_base_attack_response_direction",
			ActionDef.Action.BIG_ATTACK,
			ActionDef.Action.ATTACK))
	stage.shake(16.0, p2_big_direction)
	var immediate_gust := float(
			near_material.get_shader_parameter("gust_strength"))
	var immediate_mid_far_gust := float(
			mid_far_material.get_shader_parameter("gust_strength"))
	var immediate_cover_back_gust := float(
			cover_back_material.get_shader_parameter("gust_strength"))
	var p2_source_x := gust_particles.position.x
	await _wait_real_msec(80)
	var peak_gust := float(
			near_material.get_shader_parameter("gust_strength"))
	await _shot(ProbeOutput.path("scene5_wind_p2_big_right_to_left.png"))
	await _wait_real_msec(1480)
	var recovered_gust := float(
			near_material.get_shader_parameter("gust_strength"))
	stage.shake(16.0, p1_big_direction)
	var p1_source_x := gust_particles.position.x
	await _wait_real_msec(80)
	await _shot(ProbeOutput.path("scene5_wind_p1_big_left_to_right.png"))
	await _wait_real_msec(1480)
	stage.shake(16.0, 0.0)
	var dual_source_x := gust_particles.position.x
	var dual_direction := float(
			near_material.get_shader_parameter("gust_direction"))
	await _wait_real_msec(80)
	await _shot(ProbeOutput.path("scene5_wind_equal_waves_dual.png"))
	await _wait_real_msec(1480)
	await _shot(ProbeOutput.path("scene5_wind_recovered.png"))
	var curve_start := float(wind_field.call("response_strength_at", 0.0))
	var curve_early := float(wind_field.call("response_strength_at", 0.2))
	var curve_middle := float(wind_field.call("response_strength_at", 0.4))

	var passed := (
			immediate_gust >= 0.99
			and immediate_mid_far_gust >= 0.99
			and immediate_cover_back_gust >= 0.99
			and peak_gust >= 0.75
			and recovered_gust <= 0.01
			and p2_big_direction == -1.0
			and p1_big_direction == 1.0
			and p2_source_x > 1500.0
			and p1_source_x < 420.0
			and dual_direction == 0.0
			and dual_source_x > 900.0
			and dual_source_x < 1020.0
			and cloud_moves_left_to_right
			and float(far_material.get_shader_parameter(
					"field_wave_strength")) >= 0.8
			and float(far_material.get_shader_parameter(
					"field_wave_speed")) <= 0.025
			and float(far_material.get_shader_parameter(
					"field_highlight_rest")) == 1.0
			and is_equal_approx(
					float(distant_material.get_shader_parameter("wave_speed")),
					float(far_material.get_shader_parameter("field_wave_speed")))
			and is_equal_approx(
					float(distant_material.get_shader_parameter("wave_phase")),
					float(far_material.get_shader_parameter("field_wave_phase")))
			and float(distant_material.get_shader_parameter(
					"light_strength")) >= 0.55
			and float(far_material.get_shader_parameter(
					"shape_wave_vertical_px")) >= 3.5
			and float(far_material.get_shader_parameter(
					"shape_wave_horizontal_px")) >= 2.0
			and int(mid_far_wheat.get("mesh_columns")) >= 80
			and int(mid_far_wheat.get("mesh_rows")) >= 18
			and float(mid_far_material.get_shader_parameter(
					"shape_wave_vertical_px")) >= 2.0
			and float(mid_far_material.get_shader_parameter(
					"shape_wave_vertical_px")) <= 3.2
			and float(mid_far_material.get_shader_parameter(
					"shape_wave_horizontal_px")) >= 1.0
			and float(mid_far_material.get_shader_parameter(
					"shape_wave_horizontal_px")) <= 2.2
			and float(mid_far_material.get_shader_parameter(
					"field_wave_speed"))
					< float(far_material.get_shader_parameter("field_wave_speed"))
			and float(mid_far_material.get_shader_parameter(
					"depth_haze_strength"))
					> float(far_material.get_shader_parameter("depth_haze_strength"))
			and float(stage.get_node("DistantWheat").get_meta("parallax_factor"))
					< float(mid_far_wheat.get_meta("parallax_factor"))
			and float(mid_far_wheat.get_meta("parallax_factor"))
					< float(far_wheat.get_meta("parallax_factor"))
			and stage.get_node("DistantWheat").get_index() < mid_far_wheat.get_index()
			and mid_far_wheat.get_index() < far_wheat.get_index()
			and far_wheat.get_index() < cover_back.get_index()
			and cover_back.get_index() < stage.get_node("MidFieldHaze").get_index()
			and int(cover_back.get("mesh_columns")) >= 88
			and float(cover_back_material.get_shader_parameter("clip_top")) >= 0.36
			and int(far_wheat.get("mesh_columns")) >= 128
			and int(far_wheat.get("mesh_rows")) >= 24
			and float(distant_material.get_shader_parameter(
					"bottom_edge_trim")) >= 0.8
			and curve_start - curve_early > curve_early - curve_middle
			and gust_particles.one_shot
			and ambient_particles.amount >= 12
			and float(far_material.get_shader_parameter("cluster_count")) >= 8.0)
	print(
			"SCENE5_WIND_PROBE: ",
			"PASS" if passed else "FAIL",
			" immediate_gust=",
			immediate_gust,
			" immediate_mid_far_gust=",
			immediate_mid_far_gust,
			" cover_back_gust=",
			immediate_cover_back_gust,
			" peak_gust=",
			peak_gust,
			" recovered_gust=",
			recovered_gust,
			" curve=",
			Vector3(curve_start, curve_early, curve_middle),
			" sources=",
			Vector3(p2_source_x, p1_source_x, dual_source_x),
			" cloud_bands=",
			upper_cloud.get_child_count(),
			" cloud_left_to_right=",
			cloud_moves_left_to_right,
			" far_wave=",
			far_material.get_shader_parameter("field_wave_strength"),
			" mid_far_wave=",
			mid_far_material.get_shader_parameter("field_wave_strength"),
			" ambient_amount=",
			ambient_particles.amount,
			" gust_amount=",
			gust_particles.amount)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error(
				"Scene5 wind probe could not save %s (error=%d)"
				% [path, error])


func _wait_real_msec(duration_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_msec
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
