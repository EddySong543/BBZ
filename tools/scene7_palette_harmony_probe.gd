extends SceneTree

const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"

const SKY_SHADER := "res://assets/shaders/canvas_env_scene7_sky_grade.gdshader"
const BIOLUME_GLOW_SHADER := \
		"res://assets/shaders/canvas_env_scene7_biolume_glow_fx.gdshader"
const BIOLUME_RELIGHT_SHADER := \
		"res://assets/shaders/canvas_env_scene7_biolume_cluster_relight.gdshader"
const SURFACE := Color(0.133, 0.667, 0.6, 1.0)
const DEEP := Color(0.067, 0.267, 0.4, 1.0)
const GLOW := Color(0.44, 0.88, 0.72, 1.0)


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate() as Control
	root.add_child(screen)
	await process_frame
	var stage := screen.get_node("StageSlot/Stage") as BattleStage

	var water_palette_ready := true
	for node_name: String in ["RearWater", "RearWaterReflection", "FrontWater"]:
		var material := (stage.get_node(node_name) as CanvasItem).material as ShaderMaterial
		water_palette_ready = (
				water_palette_ready
				and material.resource_local_to_scene
				and material.get_shader_parameter("surface_color") == SURFACE
				and material.get_shader_parameter("deep_color") == DEEP
				and material.get_shader_parameter("spring_glow_color") == GLOW)
	var contact_material := (
			stage.get_node("PlatformSpringContact") as ColorRect).material as ShaderMaterial
	water_palette_ready = (
			water_palette_ready
			and contact_material.resource_local_to_scene
			and contact_material.get_shader_parameter("surface_color") == SURFACE
			and contact_material.get_shader_parameter("spring_glow_color") == GLOW)

	var plant_palette_ready := true
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var glow: Color = material.get_shader_parameter("glow_color")
		plant_palette_ready = (
				plant_palette_ready
				and material.resource_local_to_scene
				and glow.h * 360.0 >= 155.0
				and glow.h * 360.0 <= 175.0
				and glow.v >= 0.82
				and glow.v <= 0.90
				and float(material.get_shader_parameter("source_cyan_compression")) >= 0.17
				and float(material.get_shader_parameter("source_cyan_compression")) <= 0.19
				and float(material.get_shader_parameter("core_preservation")) <= 0.86
				and float(material.get_shader_parameter("source_cyan_midtone_lift")) >= 0.07
				and float(material.get_shader_parameter("source_cyan_midtone_lift")) <= 0.085
				and float(material.get_shader_parameter("base_brightness")) >= 0.88
				and float(material.get_shader_parameter("base_brightness")) <= 0.93
				and float(material.get_shader_parameter("palette_strength")) >= 0.35
				and float(material.get_shader_parameter("palette_strength")) <= 0.39
				and is_zero_approx(float(material.get_shader_parameter(
						"point_twinkle_strength")))
				and is_zero_approx(float(material.get_shader_parameter(
						"cluster_breathe_strength")))
				and is_zero_approx(float(material.get_shader_parameter(
						"glow_pulse_strength")))
				and is_zero_approx(float(material.get_shader_parameter(
						"edge_motion_strength")))
				and float(material.get_shader_parameter("highlight_shoulder_strength")) >= 1.2)

	var biolume_fx_ready := true
	var glow_contract := {
		"MidgroundLeftGlowFX": ["MidgroundLeft", true, false, false],
		"MidgroundCenterGlowFX": ["MidgroundCenter", true, false, false],
		"MidgroundCenterGrassGlowFX": ["MidgroundCenter", false, true, true],
		"MidgroundRightGlowFX": ["MidgroundRight", true, false, false],
		"MidgroundRightGrassGlowFX": ["MidgroundRight", false, true, true],
		"ForegroundLeftGlowFX": ["ForegroundLeft", true, false, false],
	}
	for glow_name: String in glow_contract:
		var contract: Array = glow_contract[glow_name]
		var source := stage.get_node(contract[0]) as TextureRect
		var expects_points: bool = contract[1]
		var expects_cluster: bool = contract[2]
		var expects_relight: bool = contract[3]
		var overlay := stage.get_node_or_null(glow_name) as MeshInstance2D
		if overlay == null:
			biolume_fx_ready = false
			continue
		var glow_material := overlay.material as ShaderMaterial
		biolume_fx_ready = (
				biolume_fx_ready
				and overlay.texture == source.texture
				and overlay.position.is_equal_approx(source.position)
				and overlay.scale.is_equal_approx(source.scale)
				and glow_material != null
				and glow_material.resource_local_to_scene
				and glow_material.shader.resource_path == (
						BIOLUME_RELIGHT_SHADER if expects_relight
						else BIOLUME_GLOW_SHADER))
		if expects_points:
			biolume_fx_ready = (
					biolume_fx_ready
					and int(overlay.get_meta("point_component_count", 0)) >= 3
					and int(overlay.get_meta("point_core_pixel_count", 0)) >= 3
					and int(overlay.get_meta("point_halo_pixel_count", 0))
							> int(overlay.get_meta("point_core_pixel_count", 0))
					and float(glow_material.get_shader_parameter(
							"point_core_peak")) >= 0.22
					and float(glow_material.get_shader_parameter(
							"point_halo_peak")) >= 0.10
					and float(glow_material.get_shader_parameter(
							"point_cycle_sec")) >= 7.0)
		else:
			biolume_fx_ready = (
					biolume_fx_ready
					and int(overlay.get_meta("point_component_count", 0)) == 0)
		if expects_cluster:
			biolume_fx_ready = (
					biolume_fx_ready
					and int(overlay.get_meta("cluster_core_pixel_count", 0)) >= 40
					and int(overlay.get_meta("cluster_halo_pixel_count", 0)) >= 20
					and float(glow_material.get_shader_parameter(
							"cluster_cycle_sec")) >= 9.0
					and (not expects_relight
							or float(glow_material.get_shader_parameter(
									"trough_brightness")) <= 0.75))
		else:
			biolume_fx_ready = (
					biolume_fx_ready
					and int(overlay.get_meta("cluster_core_pixel_count", 0)) == 0)

	var far_material := (stage.get_node("FarBackground") as TextureRect).material as ShaderMaterial
	var background_palette_ready := (
			far_material.resource_local_to_scene
			and float(far_material.get_shader_parameter("far_saturation_retention")) >= 0.92
			and float(far_material.get_shader_parameter("near_saturation_retention")) >= 0.98
			and float(far_material.get_shader_parameter("air_strength")) <= 0.08
			and float(far_material.get_shader_parameter(
					"sand_palette_strength")) >= 0.96
			and float(far_material.get_shader_parameter(
					"sand_saturation")) >= 1.12
			and float(far_material.get_shader_parameter(
					"sand_saturation")) <= 1.20
			and float(far_material.get_shader_parameter(
					"source_value_detail")) >= 0.28
			and float(far_material.get_shader_parameter(
					"source_value_detail")) <= 0.35)

	var sky_material := (stage.get_node("Sky") as TextureRect).material as ShaderMaterial
	var sky_palette_ready: bool = (
			sky_material != null
			and sky_material.resource_local_to_scene
			and sky_material.shader.resource_path == SKY_SHADER
			and sky_material.get_shader_parameter("zenith_color")
					== Color(0.58, 0.82, 0.69, 1.0)
			and sky_material.get_shader_parameter("horizon_color")
					== Color(0.7, 0.9, 0.72, 1.0)
			and float(sky_material.get_shader_parameter("palette_strength")) >= 0.24
			and float(sky_material.get_shader_parameter("palette_strength")) <= 0.32)

	var foreground_palette_ready := true
	for node_name: String in ["ForegroundLeft", "ForegroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		var shadow: Color = material.get_shader_parameter("shadow_palette")
		var sunlit: Color = material.get_shader_parameter("sunlit_palette")
		foreground_palette_ready = (
				foreground_palette_ready
				and material.resource_local_to_scene
				and float(material.get_shader_parameter("palette_strength")) >= 0.38
				and shadow.b > shadow.g * 2.0
				and sunlit.g > sunlit.r * 3.5)

	var platform_material := (
			stage.get_node("BattlePlatform") as TextureRect).material as ShaderMaterial
	var underside: Color = platform_material.get_shader_parameter("underside_tint")
	var platform_palette_ready: bool = (
			platform_material.resource_local_to_scene
			and underside.h * 360.0 >= 285.0
			and underside.h * 360.0 <= 315.0
			and float(platform_material.get_shader_parameter("underside_strength")) >= 0.78)

	var character_neutral_ready := true
	for node_name: String in ["P1CharDisplay", "P2CharDisplay"]:
		var display := screen.get_node("WorldGroup/%s" % node_name) as CharacterDisplay
		var sprite := display.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		if material == null:
			character_neutral_ready = false
			continue
		character_neutral_ready = (
				character_neutral_ready
				and material.resource_local_to_scene
				and is_equal_approx(float(material.get_shader_parameter("source_saturation")), 1.0)
				and is_equal_approx(float(material.get_shader_parameter("source_contrast")), 1.0)
				and is_zero_approx(float(material.get_shader_parameter("ambient_tint_amount")))
				and is_zero_approx(float(material.get_shader_parameter("rim_strength")))
				and is_zero_approx(float(material.get_shader_parameter("fill_amount")))
				and is_zero_approx(float(material.get_shader_parameter("daylight_key_amount")))
				and is_zero_approx(float(material.get_shader_parameter("water_bounce_amount"))))

	var post_material := (screen.get_node("PostFX") as ColorRect).material as ShaderMaterial
	var post_neutral_ready := (
			post_material.resource_local_to_scene
			and is_equal_approx(float(post_material.get_shader_parameter("brightness")), 1.0)
			and is_equal_approx(float(post_material.get_shader_parameter("contrast")), 1.0)
			and is_equal_approx(float(post_material.get_shader_parameter("saturation")), 1.0)
			and is_zero_approx(float(post_material.get_shader_parameter("tint_strength")))
			and is_zero_approx(float(post_material.get_shader_parameter("split_strength")))
			and is_zero_approx(float(post_material.get_shader_parameter("vignette_strength"))))

	var ui_material := (
			screen.get_node("UiReadabilityVeil") as ColorRect).material as ShaderMaterial
	var ui_local_ready: bool = (
			ui_material.resource_local_to_scene
			and ui_material.get_shader_parameter("support_tint")
					== Color(0.1, 0.24, 0.28, 1.0)
			and is_zero_approx(float(ui_material.get_shader_parameter(
					"hud_support_strength")))
			and is_zero_approx(float(ui_material.get_shader_parameter(
					"timer_support_strength"))))
	var passed: bool = (
			water_palette_ready
			and plant_palette_ready
			and biolume_fx_ready
			and background_palette_ready
			and sky_palette_ready
			and foreground_palette_ready
			and platform_palette_ready
			and character_neutral_ready
			and post_neutral_ready
			and ui_local_ready)
	print(
			"SCENE7_PALETTE_HARMONY: ", "PASS" if passed else "FAIL",
			" water=", water_palette_ready,
			" plants=", plant_palette_ready,
			" biolume_fx=", biolume_fx_ready,
			" background=", background_palette_ready,
			" sky=", sky_palette_ready,
			" foreground=", foreground_palette_ready,
			" platform=", platform_palette_ready,
			" characters_neutral=", character_neutral_ready,
			" post_neutral=", post_neutral_ready,
			" ui_local=", ui_local_ready)
	screen.queue_free()
	quit(0 if passed else 1)
