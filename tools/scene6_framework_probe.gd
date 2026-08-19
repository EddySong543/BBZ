extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen6.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var platform := stage.get_node("BattlePlatform") as Control
	var magma := stage.get_node("MagmaLake") as ColorRect
	var world := screen.get_node("WorldGroup") as Control
	var p1 := screen.get_node("WorldGroup/P1CharDisplay") as CharacterDisplay
	var p2 := screen.get_node("WorldGroup/P2CharDisplay") as CharacterDisplay
	var mid_ash := stage.get_node("MidAshBack") as ColorRect
	stage.set_process(false)
	screen.set_process(false)
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_center_x: float = platform.position.x
	var world_center_x: float = world.position.x
	await _shot(ProbeOutput.path("scene6_chilu_valley_center.png"))
	var character_stability := await _measure_character_stability(p1, p2, 18, 0.08)
	mid_ash.visible = false
	await get_tree().process_frame
	await _shot(ProbeOutput.path("scene6_depth_layers_off.png"))
	mid_ash.visible = true
	await get_tree().process_frame
	await _shot(ProbeOutput.path("scene6_depth_layers_on.png"))

	var magma_material := magma.material.duplicate(true) as ShaderMaterial
	magma.material = magma_material
	var phase_contract: Array[Array] = [
		[0.0, "00"],
		[0.25, "25"],
		[0.5, "50"],
		[0.75, "75"],
		[1.0, "100"],
	]
	for phase_entry: Array in phase_contract:
		magma_material.set_shader_parameter("phase_override", phase_entry[0] as float)
		await get_tree().process_frame
		await _shot(ProbeOutput.path(
				"scene6_magma_phase_%s.png" % (phase_entry[1] as String)))
	var loop_image_zero := await _render_magma_sample(magma_material, 0.0)
	var loop_image_one := await _render_magma_sample(magma_material, 1.0)
	loop_image_zero.save_png(ProbeOutput.path("scene6_magma_isolated_phase_00.png"))
	loop_image_one.save_png(ProbeOutput.path("scene6_magma_isolated_phase_100.png"))
	var loop_diff_pixels := _count_pixel_differences(loop_image_zero, loop_image_one)
	var magma_visible_pixels := _count_visible_pixels(loop_image_zero)
	var magma_hot_pixels := _count_hot_pixels(loop_image_zero)
	var magma_lumas: Array[float] = [_average_visible_luma(loop_image_zero)]
	for sample_phase: float in [0.25, 0.5, 0.75]:
		magma_lumas.append(_average_visible_luma(
				await _render_magma_sample(magma_material, sample_phase)))
	var magma_luma_min := magma_lumas.min() as float
	var magma_luma_max := magma_lumas.max() as float
	var magma_luma_amplitude := magma_luma_max - magma_luma_min
	magma_material.set_shader_parameter("phase_override", -1.0)

	await get_tree().create_timer(2.0).timeout
	await _shot(ProbeOutput.path("scene6_chilu_valley_magma_later.png"))
	p1.pulse_rim(1.4, 0.3)
	p2.pulse_rim(1.4, 0.3)
	await get_tree().process_frame
	await _shot(ProbeOutput.path("scene6_chilu_valley_rim_peak.png"))
	await get_tree().create_timer(0.35).timeout

	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.p1_frames[1].gui_input.emit(click)
	var switch_armed: bool = (
		screen._armed_switch_frame == 1
		and screen.p1_frames[1].get_node("SwitchPrompt").visible)
	await _shot(ProbeOutput.path("scene6_chilu_valley_switch_armed.png"))

	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_delta: float = platform.position.x - platform_center_x
	var world_delta: float = world.position.x - world_center_x
	var sync_error: float = absf(platform_delta - world_delta)
	await _shot(ProbeOutput.path("scene6_chilu_valley_pointer_right.png"))

	var required_nodes: Array[String] = [
		"P1Hud",
		"P2Hud",
		"Buttons",
		"DeathSwitchOverlay",
		"WorldGroup/P1CharDisplay",
		"WorldGroup/P2CharDisplay",
	]
	var missing_nodes: Array[String] = []
	for node_path: String in required_nodes:
		if screen.get_node_or_null(node_path) == null:
			missing_nodes.append(node_path)

	var p1_material := (p1.get_node(
			"SubViewport/AnimatedSprite2D") as AnimatedSprite2D).material as ShaderMaterial
	var p2_material := (p2.get_node(
			"SubViewport/AnimatedSprite2D") as AnimatedSprite2D).material as ShaderMaterial
	var characters_ready := (
		p1.get_render_texture() != null
		and p2.get_render_texture() != null
		and p1.visible
		and p2.visible
		and (p1_material.get_shader_parameter("light_dir") as Vector2).x < 0.0
		and (p2_material.get_shader_parameter("light_dir") as Vector2).x > 0.0
		and (p1_material.get_shader_parameter("rim_strength_cap") as float) <= 0.04
		and (p2_material.get_shader_parameter("rim_strength_cap") as float) <= 0.04
		and is_zero_approx(p1_material.get_shader_parameter("flash_peak_strength") as float)
		and is_zero_approx(p2_material.get_shader_parameter("flash_peak_strength") as float)
		and (screen.get_node("WorldGroup/P1Shadow") as TextureRect).self_modulate.r < 0.4
		and (screen.get_node("WorldGroup/P2Shadow") as TextureRect).self_modulate.r < 0.4)
	var platform_node := stage.get_node("BattlePlatform") as NinePatchRect
	var depth_heat_veil := stage.get_node_or_null("DepthHeatVeil") as ColorRect
	var magma_occluded := (
		magma != null
		and magma.get_index() < platform_node.get_index()
		and platform_node.get_index() < stage.get_node("ForegroundLeft").get_index()
		and magma.position.y >= 830.0
		and magma.position.y <= 890.0)
	var environment_ready: bool = (
		String(stage.get_meta("theme_name", "")) == "赤炉剑谷"
		and (stage.get_node("FarBackground") as TextureRect).texture != null
		and (stage.get_node("MidgroundLeft") as TextureRect).texture != null
		and (stage.get_node("MidgroundRight") as TextureRect).texture != null
		and (stage.get_node("ForegroundLeft") as TextureRect).texture != null
		and (stage.get_node("ForegroundRight") as TextureRect).texture != null
		and (stage.get_node("BattlePlatform") as NinePatchRect).texture != null
		and stage.get_node_or_null("ForgeAbyss") == null
		and stage.get_node_or_null("ForgeCore") == null
		and stage.get_node_or_null("PlatformForgeContact") == null
		and stage.get_node_or_null("UnderbridgeForge") == null
		and stage.get_node_or_null("FarSmokeBanks") == null
		and stage.get_node_or_null("MidAshBack") is ColorRect
		and depth_heat_veil != null
		and depth_heat_veil.material is ShaderMaterial
		and depth_heat_veil.get_index() > stage.get_node("FarBackground").get_index()
		and depth_heat_veil.get_index() < stage.get_node("MidgroundLeft").get_index()
		and magma_occluded
		and magma.visible
		and magma.material is ShaderMaterial
		and (stage.get_node("ThermalAtmosphere") as ColorRect).material is ShaderMaterial
		and (stage.get_node("ForegroundEmbers") as ColorRect).material is ShaderMaterial
		and (stage.get_node("MidgroundLeft") as TextureRect).material is ShaderMaterial
		and (stage.get_node("MidgroundRight") as TextureRect).material is ShaderMaterial
		and ((screen.get_node("PostFX") as ColorRect).material as ShaderMaterial).get_shader_parameter(
				"heat_haze_strength") as float >= 1.0
		and ((screen.get_node("PostFX") as ColorRect).material as ShaderMaterial).get_shader_parameter(
				"heat_haze_character_protection") as float >= 0.99)
	var passed: bool = (
		not stage.get_meta("framework_only", true)
		and environment_ready
		and absf(platform_delta) > 2.0
		and sync_error < 0.05
		and loop_diff_pixels == 0
		and magma_luma_amplitude <= 0.035
		and magma_visible_pixels > 32768
		and magma_hot_pixels > 256
		and switch_armed
		and characters_ready
		and character_stability.x <= 0.025
		and character_stability.y <= 0.025
		and missing_nodes.is_empty())
	print(
			"SCENE6_CHILU_VALLEY_PROBE: ",
			"PASS" if passed else "FAIL",
			" platform_delta=",
			platform_delta,
			" world_delta=",
			world_delta,
			" error=",
			sync_error,
			" switch_armed=",
			switch_armed,
			" characters_ready=",
			characters_ready,
			" environment_ready=",
			environment_ready,
			" loop_diff_pixels=",
			loop_diff_pixels,
			" magma_visible_pixels=",
			magma_visible_pixels,
			" magma_hot_pixels=",
			magma_hot_pixels,
			" magma_luma_amplitude=",
			magma_luma_amplitude,
			" character_luma_delta=",
			character_stability,
			" missing=",
			missing_nodes)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error(
				"Scene6 framework probe could not save %s (error=%d)"
				% [path, error])


func _measure_character_stability(
		p1: CharacterDisplay,
		p2: CharacterDisplay,
		sample_count: int,
		interval: float) -> Vector2:
	var p1_min := Vector4(INF, INF, INF, INF)
	var p1_max := Vector4(-INF, -INF, -INF, -INF)
	var p2_min := Vector4(INF, INF, INF, INF)
	var p2_max := Vector4(-INF, -INF, -INF, -INF)
	for _sample_index: int in sample_count:
		await get_tree().create_timer(interval).timeout
		var p1_profile := _character_color_profile(p1)
		var p2_profile := _character_color_profile(p2)
		p1_min = p1_min.min(p1_profile)
		p1_max = p1_max.max(p1_profile)
		p2_min = p2_min.min(p2_profile)
		p2_max = p2_max.max(p2_profile)
	print(
			"SCENE6_CHARACTER_STABILITY: p1_delta=", p1_max - p1_min,
			" p2_delta=", p2_max - p2_min,
			" channels=rgb_luma")
	return Vector2(p1_max.w - p1_min.w, p2_max.w - p2_min.w)


func _character_color_profile(display: CharacterDisplay) -> Vector4:
	var image := display.get_render_texture().get_image()
	image.resize(96, 96, Image.INTERPOLATE_NEAREST)
	var sum := Vector3.ZERO
	var visible_count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var sample := image.get_pixel(x, y)
			if sample.a <= 0.05:
				continue
			sum += Vector3(sample.r, sample.g, sample.b)
			visible_count += 1
	if visible_count == 0:
		return Vector4.ZERO
	var average := sum / float(visible_count)
	var luma := average.dot(Vector3(0.299, 0.587, 0.114))
	return Vector4(average.x, average.y, average.z, luma)


func _render_magma_sample(source_material: ShaderMaterial, phase: float) -> Image:
	var sample_viewport := SubViewport.new()
	sample_viewport.size = Vector2i(512, 128)
	sample_viewport.transparent_bg = true
	sample_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sample_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sample_viewport)
	var sample_rect := ColorRect.new()
	sample_rect.size = Vector2(512.0, 128.0)
	var sample_material := source_material.duplicate(true) as ShaderMaterial
	sample_material.set_shader_parameter("size_px", Vector2(512.0, 128.0))
	sample_material.set_shader_parameter("phase_override", phase)
	sample_rect.material = sample_material
	sample_viewport.add_child(sample_rect)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := sample_viewport.get_texture().get_image()
	sample_viewport.queue_free()
	return image


func _count_pixel_differences(first: Image, second: Image) -> int:
	if first == null or second == null:
		return -1
	if first.get_size() != second.get_size():
		return -1
	var differences: int = 0
	for y: int in first.get_height():
		for x: int in first.get_width():
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				differences += 1
	return differences


func _count_visible_pixels(image: Image) -> int:
	var visible: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.9:
				visible += 1
	return visible


func _count_hot_pixels(image: Image) -> int:
	var hot: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.9 and color.r > 0.35 and color.r > color.g * 1.8:
				hot += 1
	return hot


func _average_visible_luma(image: Image) -> float:
	var total := 0.0
	var visible := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.9:
				continue
			total += color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			visible += 1
	return total / float(maxi(visible, 1))
