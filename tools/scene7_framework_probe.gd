extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")
const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var packed := load(BATTLE7_PATH) as PackedScene
	var screen := packed.instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var platform := stage.get_node("BattlePlatform") as TextureRect
	var world := screen.get_node("WorldGroup") as Control
	var p1 := screen.get_node("WorldGroup/P1CharDisplay") as CharacterDisplay
	var p2 := screen.get_node("WorldGroup/P2CharDisplay") as CharacterDisplay
	stage.set_process(false)
	screen.set_process(false)
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_center_x: float = platform.position.x
	var world_center_x: float = world.position.x
	await _shot(ProbeOutput.path("scene7_framework_center.png"))

	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.p1_frames[1].gui_input.emit(click)
	var switch_armed: bool = (
		screen._armed_switch_frame == 1
		and screen.p1_frames[1].get_node("SwitchPrompt").visible)
	await _shot(ProbeOutput.path("scene7_framework_switch_armed.png"))

	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_delta: float = platform.position.x - platform_center_x
	var world_delta: float = world.position.x - world_center_x
	var sync_error: float = absf(platform_delta - world_delta)
	await _shot(ProbeOutput.path("scene7_framework_pointer_right.png"))

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

	var expected_factors: Dictionary[String, float] = {
		"Sky": 0.0,
		"FarBackground": 0.18,
		"Midground": 0.55,
		"BattlePlatform": 1.0,
		"Foreground": 1.25,
	}
	var flat_layers_ready: bool = true
	for node_name: String in expected_factors:
		var layer := stage.get_node_or_null(node_name) as TextureRect
		flat_layers_ready = flat_layers_ready and layer != null
		if layer == null:
			continue
		flat_layers_ready = (
			flat_layers_ready
			and layer.get_parent() == stage
			and layer.texture == null
			and layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and is_equal_approx(
				float(layer.get_meta("parallax_factor")),
				expected_factors[node_name]))

	var characters_ready: bool = (
		p1.get_render_texture() != null
		and p2.get_render_texture() != null
		and p1.visible
		and p2.visible
		and is_zero_approx(p1.rim_strength)
		and is_zero_approx(p2.rim_strength)
		and is_zero_approx(p1.backlight)
		and is_zero_approx(p2.backlight)
		and is_zero_approx(p1.warmth_amount)
		and is_zero_approx(p2.warmth_amount)
		and is_zero_approx(p1.fill_amount)
		and is_zero_approx(p2.fill_amount))
	var post_material := (screen.get_node("PostFX") as ColorRect).material as ShaderMaterial
	var neutral_postfx: bool = (
		post_material != null
		and is_equal_approx(
			float(post_material.get_shader_parameter("brightness")), 1.0)
		and is_zero_approx(
			float(post_material.get_shader_parameter("tint_strength")))
		and is_zero_approx(
			float(post_material.get_shader_parameter("heat_haze_strength"))))
	var particles_disabled: bool = true
	for dust_name: String in ["ForeDust", "LowerDust"]:
		var dust := screen.get_node(dust_name) as GPUParticles2D
		particles_disabled = particles_disabled and not dust.visible and not dust.emitting

	var passed: bool = (
		stage.scene_file_path == SCENE7_PATH
		and bool(stage.get_meta("framework_only", false))
		and flat_layers_ready
		and characters_ready
		and neutral_postfx
		and particles_disabled
		and absf(platform_delta) > 2.0
		and sync_error < 0.05
		and switch_armed
		and missing_nodes.is_empty())
	print(
		"SCENE7_FRAMEWORK_PROBE: ",
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
		" flat_layers_ready=",
		flat_layers_ready,
		" neutral_postfx=",
		neutral_postfx,
		" particles_disabled=",
		particles_disabled,
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
			"Scene7 framework probe could not save %s (error=%d)"
			% [path, error])
