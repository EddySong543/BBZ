extends SceneTree

## 无截图共享战斗特效契约：逐个实例化 Scene1-7，确认黑白冲击帧的三段材质状态
## 实际运行，并检查任何场景专属全屏采样层都位于共享 PostFX 之前。

const SCREEN_PATHS: Array[String] = [
	"res://src/ui/battle_screen1.tscn",
	"res://src/ui/battle_screen2.tscn",
	"res://src/ui/battle_screen3.tscn",
	"res://src/ui/battle_screen4.tscn",
	"res://src/ui/battle_screen5.tscn",
	"res://src/ui/battle_screen6.tscn",
	"res://src/ui/battle_screen7.tscn",
]
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var failures: Array[String] = []
	for scene_index: int in SCREEN_PATHS.size():
		var scene_label := "Scene%d" % (scene_index + 1)
		var packed := load(SCREEN_PATHS[scene_index]) as PackedScene
		if packed == null:
			failures.append("%s battle scene failed to load" % scene_label)
			continue
		var screen := packed.instantiate() as Control
		root.add_child(screen)
		print("BATTLE_SHARED_FX_SETUP: %s" % scene_label)
		await process_frame
		await process_frame
		if not is_instance_valid(screen):
			failures.append("%s battle screen exited during setup" % scene_label)
			continue
		var post_fx := screen.get_node_or_null("PostFX") as ColorRect
		var world_grab := screen.get_node_or_null("WorldGrab") as BackBufferCopy
		if post_fx == null or world_grab == null:
			failures.append("%s lacks the shared WorldGrab/PostFX chain" % scene_label)
			screen.free()
			continue
		if world_grab.get_index() >= post_fx.get_index():
			failures.append("%s draws PostFX before its WorldGrab source" % scene_label)
		var readability_veil := screen.get_node_or_null("UiReadabilityVeil") as ColorRect
		if readability_veil != null:
			var post_readability_grab := screen.get_node_or_null(
					"UiReadabilityPostGrab") as BackBufferCopy
			if post_readability_grab == null \
					or not (world_grab.get_index() < readability_veil.get_index() \
					and readability_veil.get_index() < post_readability_grab.get_index() \
					and post_readability_grab.get_index() < post_fx.get_index()) \
					or post_readability_grab.copy_mode != BackBufferCopy.COPY_MODE_VIEWPORT:
				failures.append(
						"%s readability chain does not preserve world then PostFX" % scene_label)
		var stage := screen.get("stage") as BattleStage
		if stage == null or not stage.pointer_parallax or stage.demo_click_shake:
			failures.append("%s changed the mature mouse-parallax contract" % scene_label)
		var world_group := screen.get_node_or_null("WorldGroup") as Control
		if world_group == null or world_group.get_index() >= world_grab.get_index():
			failures.append("%s world/characters are outside the root capture" % scene_label)
		for ui_path: String in ["P1Hud", "P2Hud", "Buttons", "DeathSwitchOverlay"]:
			if not screen.has_node(ui_path):
				failures.append("%s lost shared UI node %s" % [scene_label, ui_path])
		for child: Node in screen.get_children():
			if child.get_index() <= post_fx.get_index() or not child is ColorRect:
				continue
			var rect := child as ColorRect
			var material := rect.material as ShaderMaterial
			if material == null or material.shader == null:
				continue
			if material.shader.code.contains("hint_screen_texture"):
				failures.append(
						"%s fullscreen reader %s redraws after PostFX" \
						% [scene_label, child.name])

		var post_material := post_fx.material as ShaderMaterial
		if post_material == null or post_material.shader == null:
			failures.append("%s PostFX has no shader material" % scene_label)
			screen.free()
			continue
		for shader_token: String in [
			"impact_strength",
			"impact_invert",
			"impact_center",
			"impact_white",
		]:
			if not post_material.shader.code.contains(shader_token):
				failures.append("%s PostFX shader lacks %s" % [scene_label, shader_token])

		var battle_fx := screen.get("_fx") as Node
		if battle_fx == null or not battle_fx.has_method("_bw_flash"):
			failures.append("%s did not initialize the shared BattleFx flash" % scene_label)
			screen.free()
			continue
		post_material.set_shader_parameter("impact_strength", 0.0)
		post_material.set_shader_parameter("impact_invert", 0.0)
		battle_fx.call("_bw_flash", Vector2(0.5, 0.55))
		if not is_equal_approx(float(post_material.get_shader_parameter("impact_strength")), 1.0) \
				or not is_zero_approx(float(post_material.get_shader_parameter("impact_invert"))):
			failures.append("%s flash did not enter the positive black-white frame" % scene_label)
		await create_timer(0.10, true, false, true).timeout
		if not is_equal_approx(float(post_material.get_shader_parameter("impact_strength")), 1.0) \
				or not is_equal_approx(float(post_material.get_shader_parameter("impact_invert")), 1.0):
			failures.append("%s flash did not enter the inverse frame" % scene_label)
		await create_timer(0.08, true, false, true).timeout
		if not is_zero_approx(float(post_material.get_shader_parameter("impact_strength"))):
			failures.append("%s flash did not restore PostFX after its inverse frame" % scene_label)

		var character_materials: Array[ShaderMaterial] = []
		var idle_durations: Array[float] = []
		for character_name: String in ["P1CharDisplay", "P2CharDisplay"]:
			var display := screen.get_node("WorldGroup/%s" % character_name) as CharacterDisplay
			var sprite := display.get_node("SubViewport/AnimatedSprite2D") as AnimatedSprite2D
			if not display.is_visible_in_tree() or display.modulate.a < 0.99 \
					or not sprite.is_visible_in_tree() or display.get_render_texture() == null:
				failures.append("%s %s is absent from the captured world" % [scene_label, character_name])
			if sprite.animation != &"idle" \
					or not sprite.sprite_frames.get_animation_loop(&"idle"):
				failures.append("%s %s lost its looping idle state" % [scene_label, character_name])
			var idle_duration := display.animation_duration(&"idle")
			idle_durations.append(idle_duration)
			var expected_idle_duration := float(display.idle_ref_frames) / display.idle_base_fps
			if absf(idle_duration - expected_idle_duration) > 0.01:
				failures.append(
						"%s %s idle loop drifted to %.4fs" \
						% [scene_label, character_name, idle_duration])
			var character_material := sprite.material as ShaderMaterial
			character_materials.append(character_material)
			if character_material == null or character_material.shader == null \
					or not character_material.shader.code.contains("flash_amount") \
					or not character_material.shader.code.contains("rim_strength"):
				failures.append(
						"%s %s lost the shared hit-flash/rim shader contract" \
						% [scene_label, character_name])
				continue
			display.flash_white(0.05)
			if not is_equal_approx(
					float(character_material.get_shader_parameter("flash_amount")), 1.0):
				failures.append("%s %s hit flash did not start" % [scene_label, character_name])
			await create_timer(0.08, true, false, true).timeout
			if float(character_material.get_shader_parameter("flash_amount")) > 0.01:
				failures.append("%s %s hit flash did not restore" % [scene_label, character_name])
			var base_output_material := display.material
			display.set_switch_blocks(0.5, character_name == "P1CharDisplay", 8)
			var switch_material := display.material as ShaderMaterial
			if switch_material == null or switch_material.shader.resource_path \
					!= "res://assets/shaders/canvas_ui_character_switch_blocks.gdshader":
				failures.append("%s %s lost the shared switch effect" % [scene_label, character_name])
			display.reset_switch_blocks()
			if display.material != base_output_material:
				failures.append("%s %s switch effect leaked after reset" % [scene_label, character_name])
			if not display.offset_transform_enabled \
					or not display.offset_transform_visual_only:
				failures.append("%s %s switch visual offset is not active/layout-safe" \
						% [scene_label, character_name])
		if character_materials.size() == 2 and character_materials[0] == character_materials[1]:
			failures.append("%s P1/P2 share one mutable character material" % scene_label)
		if idle_durations.size() == 2 and absf(idle_durations[0] - idle_durations[1]) > 0.01:
			failures.append("%s P1/P2 idle loops no longer share one duration" % scene_label)
		if bool(screen.get("character_reflections_enabled")):
			var reflection_material := screen.get("_character_reflection_material") as ShaderMaterial
			var display := screen.get_node("WorldGroup/P1CharDisplay") as CharacterDisplay
			var shadow := screen.get_node("WorldGroup/P1Shadow") as TextureRect
			if reflection_material == null:
				failures.append("%s enabled reflections without a runtime material" % scene_label)
			else:
				screen.call("_update_character_reflections")
				var base_rect: Vector4 = reflection_material.get_shader_parameter(
						"p1_reflection_rect")
				var base_shadow_x := shadow.position.x
				var base_shadow_visible := shadow.visible
				display.offset_transform_position = Vector2(96.0, -2.0)
				screen.call("_update_character_reflections")
				screen.call("_update_shadow", 0)
				var moved_rect: Vector4 = reflection_material.get_shader_parameter(
						"p1_reflection_rect")
				if absf((moved_rect.x - base_rect.x) - 96.0) > 0.51:
					failures.append("%s reflection did not follow the switch offset" % scene_label)
				if absf((shadow.position.x - base_shadow_x) - 96.0) > 0.51:
					failures.append("%s shadow did not follow the switch offset" % scene_label)
				display.visible = false
				screen.call("_update_character_reflections")
				screen.call("_update_shadow", 0)
				var hidden_rect: Vector4 = reflection_material.get_shader_parameter(
						"p1_reflection_rect")
				if hidden_rect.z > 0.01 or hidden_rect.w > 0.01:
					failures.append("%s reflection survived the hidden swap frame" % scene_label)
				if shadow.visible:
					failures.append("%s shadow survived the hidden swap frame" % scene_label)
				display.visible = true
				shadow.visible = base_shadow_visible
				display.offset_transform_position = Vector2.ZERO
				screen.call("_update_character_reflections")
				screen.call("_update_shadow", 0)
		if scene_index == 6:
			var platform := stage.get_node_or_null("BattlePlatform") as TextureRect
			if platform == null or not platform.is_visible_in_tree() or platform.modulate.a < 0.99:
				failures.append("Scene7 platform is absent from the captured world")
			else:
				print(
						"BATTLE_SHARED_FX_SCENE7_CHAIN: world=%d grab=%d veil=%d post_grab=%d postfx=%d platform=visible characters=visible" \
						% [
							world_group.get_index(),
							world_grab.get_index(),
							readability_veil.get_index(),
							screen.get_node("UiReadabilityPostGrab").get_index(),
							post_fx.get_index(),
						])
		print(
				"BATTLE_SHARED_FX_SAMPLE: %s bw=3 hit_flash=2 idle=paired switch=visual-offset" \
				% scene_label)
		post_material.set_shader_parameter("impact_strength", 0.0)
		screen.free()
		await process_frame
		(root.get_node("BattleSetup") as Node).call("reset")

	if not failures.is_empty():
		for failure: String in failures:
			push_error("BATTLE_SHARED_FX_CONTRACT: %s" % failure)
		quit(1)
		return
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	if not battle_source.contains("_fx._bw_flash(bw_center)"):
		push_error("BATTLE_SHARED_FX_CONTRACT: finisher no longer dispatches the shared flash")
		quit(1)
		return
	print("BATTLE_SHARED_FX_CONTRACT_OK: scenes=7 bw_phases=3 hit_flash=14 idle_pairs=7 switch_offsets=14 parallax=7 ui=shared postfx_order=protected dispatch=present")
	quit(0)
