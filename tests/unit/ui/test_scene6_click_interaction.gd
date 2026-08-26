extends GutTest

const SCENE6 := preload("res://src/ui/scenes/scene6.tscn")


func test_scene6_click_effect_canvases_follow_visual_occlusion_order() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	var mid_fx := stage.get_node_or_null("MidgroundClickFX") as Control
	var magma_fx := stage.get_node_or_null("MagmaClickFX") as Control
	var magma_secrets := stage.get_node_or_null("MagmaSecrets") as Control
	var front_props := stage.get_node_or_null("MagmaSecretFrontProps") as Control
	var foreground_fx := stage.get_node_or_null("ForegroundClickFX") as Control
	var interaction := stage.get_node_or_null("ClickInteraction") \
			as Scene6ClickInteraction
	assert_not_null(mid_fx)
	assert_not_null(magma_fx)
	assert_not_null(magma_secrets)
	assert_not_null(front_props)
	assert_not_null(foreground_fx)
	assert_not_null(interaction)
	if mid_fx == null or magma_fx == null or magma_secrets == null \
			or front_props == null \
			or foreground_fx == null:
		return
	assert_gt(mid_fx.get_index(), stage.get_node("MidgroundRight").get_index())
	assert_lt(mid_fx.get_index(), stage.get_node("MidAshBack").get_index())
	assert_gt(magma_fx.get_index(), stage.get_node("MagmaLake").get_index())
	assert_lt(magma_fx.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_gt(magma_secrets.get_index(), magma_fx.get_index())
	assert_lt(magma_secrets.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_gt(front_props.get_index(), stage.get_node("BattlePlatform").get_index())
	assert_lt(front_props.get_index(), stage.get_node("ForegroundLeft").get_index())
	assert_lt(front_props.get_index(), stage.get_node("ForegroundRight").get_index())
	assert_false(front_props.clip_contents)
	assert_false(magma_secrets.clip_contents)
	assert_eq(magma_secrets.anchor_right, 1.0)
	assert_eq(magma_secrets.anchor_bottom, 1.0)
	assert_gt(foreground_fx.get_index(), stage.get_node("ForegroundRight").get_index())
	assert_lt(foreground_fx.get_index(), stage.get_node("ForegroundEmbers").get_index())
	assert_false(stage.demo_click_shake)


func test_magma_secret_depth_band_follows_surface_y_and_respects_foreground() -> void:
	var back_stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(back_stage)
	await get_tree().process_frame
	var back_secrets := back_stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	back_secrets.reveal_cooldown_sec = 0.0
	back_secrets.legend_roll_override = 1.0
	for _click: int in back_secrets.clicks_per_reveal:
		back_secrets.register_molten_click(Vector2(420.0, 860.0))
	assert_false(back_secrets.is_active_secret_in_front_depth())
	assert_eq(back_secrets.get_node("HiltPocketRuntime").get_parent(), back_secrets)

	var front_stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(front_stage)
	await get_tree().process_frame
	var front_secrets := front_stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	var front_layer := front_stage.get_node("MagmaSecretFrontProps") as Control
	front_secrets.reveal_cooldown_sec = 0.0
	front_secrets.legend_roll_override = 1.0
	for _click: int in front_secrets.clicks_per_reveal:
		front_secrets.register_molten_click(Vector2(1420.0, 1000.0))
	assert_true(front_secrets.is_active_secret_in_front_depth())
	assert_true(front_layer.has_node("HiltPocketRuntime"))
	assert_gt(front_layer.get_index(), front_stage.get_node("BattlePlatform").get_index())
	assert_lt(front_layer.get_index(), front_stage.get_node("ForegroundLeft").get_index())


func test_scene6_click_targets_spawn_distinct_pixel_effects() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	interaction.click_cooldown_sec = 0.0
	var foreground_point := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.FOREGROUND_SPARK,
			Rect2(0.0, 300.0, 1920.0, 780.0), 4)
	var magma_point := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(0.0, 834.0, 1920.0, 246.0), 4)
	var midground_point := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.MIDGROUND_SPIT,
			Rect2(0.0, 0.0, 1920.0, 834.0), 4)
	assert_ne(foreground_point, Vector2(-1.0, -1.0))
	assert_ne(magma_point, Vector2(-1.0, -1.0))
	assert_ne(midground_point, Vector2(-1.0, -1.0))
	if foreground_point.x < 0.0 or magma_point.x < 0.0 or midground_point.x < 0.0:
		return
	assert_true(interaction.try_trigger_at_canvas_position(foreground_point))
	assert_true(interaction.try_trigger_at_canvas_position(magma_point))
	assert_true(interaction.try_trigger_at_canvas_position(midground_point))
	assert_eq(interaction.get_trigger_count(
			Scene6ClickInteraction.InteractionKind.FOREGROUND_SPARK), 1)
	assert_eq(interaction.get_trigger_count(
			Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE), 1)
	assert_eq(interaction.get_trigger_count(
			Scene6ClickInteraction.InteractionKind.MIDGROUND_SPIT), 1)
	assert_eq((stage.get_node("ForegroundClickFX") \
			as Scene6ClickEffectCanvas).active_effect_count(), 1)
	assert_eq((stage.get_node("MagmaClickFX") \
			as Scene6ClickEffectCanvas).active_effect_count(), 1)
	assert_eq((stage.get_node("MidgroundClickFX") \
			as Scene6ClickEffectCanvas).active_effect_count(), 1)


func test_scene6_click_feedback_does_not_consume_battle_or_ui_input() -> void:
	var source := FileAccess.get_file_as_string(
			"res://src/ui/components/scene6_click_interaction.gd")
	assert_string_contains(source, "func _on_input_target_gui_input")
	assert_string_contains(source, "MOUSE_BUTTON_LEFT")
	assert_false(source.contains("accept_event"))
	assert_false(source.contains("set_input_as_handled"))
	assert_false(source.contains("func _unhandled_input"))


func test_scene6_preview_backdrop_gui_click_reaches_interaction() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var backdrop := stage.get_node("PreviewBackdrop") as Control
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	interaction.click_cooldown_sec = 0.0
	assert_eq(interaction.input_target_path, NodePath("../PreviewBackdrop"))
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(backdrop.gui_input.is_connected(
			interaction._on_input_target_gui_input))
	var foreground_point := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.FOREGROUND_SPARK,
			Rect2(0.0, 300.0, 1920.0, 780.0), 4)
	assert_ne(foreground_point, Vector2(-1.0, -1.0))
	if foreground_point.x < 0.0:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = backdrop.get_global_transform_with_canvas().affine_inverse() \
			* foreground_point
	backdrop.gui_input.emit(click)
	assert_eq(interaction.get_trigger_count(
			Scene6ClickInteraction.InteractionKind.FOREGROUND_SPARK), 1)


func test_magma_secrets_keep_one_active_and_never_queue_suppressed_rises() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	var secrets := stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	interaction.click_cooldown_sec = 0.0
	secrets.reveal_cooldown_sec = 0.0
	secrets.legend_roll_override = 1.0
	secrets.rise_duration_sec = 0.01
	secrets.float_duration_sec = 0.04
	secrets.sink_duration_sec = 0.04
	assert_eq(secrets.ordinary_scale, 2.0)
	var magma_point_left := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(120.0, 834.0, 760.0, 246.0), 4)
	var magma_point_right := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(1040.0, 834.0, 760.0, 246.0), 4)
	assert_ne(magma_point_left, Vector2(-1.0, -1.0))
	assert_ne(magma_point_right, Vector2(-1.0, -1.0))
	if magma_point_left.x < 0.0 or magma_point_right.x < 0.0:
		return
	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point_left))
	assert_eq(secrets.get_hilt_spawn_count(), 1)
	assert_eq(secrets.active_secret_count(), 1)
	assert_eq(secrets.pending_secret_count(), 0)
	assert_gt(secrets.active_ripple_count(), 0)
	var first_pocket := secrets.get_child(0) as Control
	var first_sprite := first_pocket.get_child(0) as Sprite2D
	assert_true(first_pocket.clip_contents)
	assert_eq(first_sprite.scale, Vector2(2.0, 2.0))
	var first_positions := secrets.get_active_secret_positions()
	assert_eq(first_positions.size(), 1)
	assert_lt(first_positions[0].distance_to(magma_point_left), 5.0)

	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point_right))
	assert_eq(secrets.get_suppressed_reveal_count(), 1)
	assert_eq(secrets.pending_secret_count(), 0)
	assert_eq(secrets.get_tip_spawn_count(), 0)
	assert_eq(secrets.active_secret_count(), 1)
	await get_tree().create_timer(0.20).timeout
	assert_eq(secrets.active_secret_count(), 0)
	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point_right))
	assert_eq(secrets.get_valid_click_count(), 12)
	assert_eq(secrets.get_tip_spawn_count(), 1)
	assert_eq(secrets.active_secret_count(), 1)
	assert_eq(secrets.pending_secret_count(), 0)
	var second_positions := secrets.get_active_secret_positions()
	assert_eq(second_positions.size(), 1)
	assert_lt(second_positions[0].distance_to(magma_point_right), 5.0)


func test_magma_secret_cooldown_turns_early_attempt_into_splash_only() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	var secrets := stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	interaction.click_cooldown_sec = 0.0
	secrets.reveal_cooldown_sec = 0.30
	secrets.legend_roll_override = 1.0
	secrets.rise_duration_sec = 0.01
	secrets.float_duration_sec = 0.04
	secrets.sink_duration_sec = 0.04
	var magma_point := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(120.0, 834.0, 1600.0, 246.0), 4)
	assert_ne(magma_point, Vector2(-1.0, -1.0))
	if magma_point.x < 0.0:
		return
	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point))
	await get_tree().create_timer(0.20).timeout
	assert_eq(secrets.active_secret_count(), 0)
	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point))
	assert_eq(secrets.get_suppressed_reveal_count(), 1)
	assert_eq(secrets.get_tip_spawn_count(), 0)
	assert_eq(secrets.pending_secret_count(), 0)
	# Keep a frame-scheduling margin beyond the 0.30 s wall-clock cooldown.
	await get_tree().create_timer(0.22).timeout
	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point))
	assert_eq(secrets.get_tip_spawn_count(), 1)


func test_low_probability_legendary_blade_has_distinct_runtime_contract() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	var secrets := stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	interaction.click_cooldown_sec = 0.0
	secrets.reveal_cooldown_sec = 0.0
	secrets.legend_roll_override = 0.0
	var magma_point := _find_point_for_kind(
			interaction, Scene6ClickInteraction.InteractionKind.MAGMA_BUBBLE,
			Rect2(120.0, 834.0, 1600.0, 246.0), 4)
	assert_ne(magma_point, Vector2(-1.0, -1.0))
	if magma_point.x < 0.0:
		return
	for _click: int in 4:
		assert_true(interaction.try_trigger_at_canvas_position(magma_point))
	assert_eq(secrets.get_legendary_spawn_count(), 1)
	assert_eq(secrets.get_active_kind(),
			Scene6MagmaSecrets.SecretKind.LEGENDARY_BLADE)
	assert_eq(secrets.get_last_spawn_kind(),
			Scene6MagmaSecrets.SecretKind.LEGENDARY_BLADE)
	assert_eq(secrets.active_secret_count(), 1)
	assert_gt(secrets.active_ripple_count(), 0)
	var pocket := secrets.get_active_secret_pocket()
	var sprite := pocket.get_child(0) as Sprite2D
	var aura := stage.get_node_or_null("LegendaryForgeAuraRuntime") as ColorRect
	assert_eq(pocket.name, "LegendaryPocketRuntime")
	assert_eq(sprite.name, "ChiluKingsBlade")
	var front_layer := stage.get_node("MagmaSecretFrontProps") as Control
	var expected_parent: Control = front_layer \
			if secrets.is_active_secret_in_front_depth() else secrets
	assert_eq(pocket.get_parent(), expected_parent,
			"传奇巨剑必须跟随点击液面的前后纵深层")
	assert_eq(pocket.z_index, 0,
			"传奇巨剑不得通过全局 z_index 越过外层战斗按钮")
	assert_not_null(aura)
	if aura != null:
		assert_eq(aura.get_parent(), expected_parent if expected_parent == front_layer \
				else stage)
		if expected_parent == front_layer:
			assert_lt(aura.get_index(), pocket.get_index())
		else:
			assert_lt(aura.get_index(), secrets.get_index())
		assert_eq(aura.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_gt(aura.size.x, float(sprite.texture.get_width()) * sprite.scale.x)
		assert_true(aura.material is ShaderMaterial)
	assert_eq(sprite.scale, Vector2(2.5, 2.5))
	assert_not_null(sprite.texture)
	assert_gt(secrets.legendary_rise_duration_sec,
			secrets.rise_duration_sec * 2.0)
	assert_gt(secrets.legendary_sink_duration_sec,
			secrets.sink_duration_sec * 1.5)
	assert_gte(secrets.legendary_float_duration_sec,
			secrets.float_duration_sec * 2.5,
			"传奇巨剑需要明显长于普通残片的悬空展示期")
	assert_gt(float(sprite.texture.get_height()) * sprite.scale.y,
			float(secrets.sword_hilt_texture.get_height()) * secrets.ordinary_scale)
	var image := sprite.texture.get_image()
	assert_not_null(image)


	if image == null:
		return
	assert_eq(image.get_size(), Vector2i(28, 64))
	var dark_shell_pixels := 0
	var molten_pixels := 0
	var core_pixels := 0
	var widest_row := -1
	var widest_row_pixels := 0
	var opaque_colors: Dictionary[Color, bool] = {}
	for y: int in image.get_height():
		var row_pixels := 0
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			row_pixels += 1
			opaque_colors[color] = true
			if maxf(color.r, maxf(color.g, color.b)) < 0.40:
				dark_shell_pixels += 1
			if color.r > 0.46 and color.r > color.g * 1.6:
				molten_pixels += 1
			if color.r > 0.92 and color.g > 0.58:
				core_pixels += 1
		if row_pixels > widest_row_pixels:
			widest_row_pixels = row_pixels
			widest_row = y
	assert_gt(dark_shell_pixels, molten_pixels * 3,
			"黑铁实体必须占主导，熔脉不能把整把剑染成均匀红金")
	assert_gt(molten_pixels, 48, "低分辨率下仍保留足够可读的熔岩裂脉")
	assert_true(core_pixels in range(4, 20), "淡金核心只作为稀疏高温点")
	assert_lte(opaque_colors.size(), 8,
			"传奇剑使用八色以内的真低分辨率熔炉色板")
	assert_gt(widest_row, int(float(image.get_height()) * 0.55),
			"原创重型剑格位于下半部，确保剑尖朝上且轮廓可读")
	var secret_code := FileAccess.get_file_as_string(
			"res://src/ui/components/scene6_magma_secrets.gd")
	for marker: String in [
		"FORGE_AURA_SHADER", "_spawn_legendary_forge_aura",
		"_update_legendary_forge_aura",
		"_legendary_light_presence", "sink_start_phase",
		"_draw_forge_surface_seams", "_draw_forge_cinders"
	]:
		assert_true(secret_code.contains(marker))
	for rejected_marker: String in [
		"_draw_forge_light_lobe", "_draw_forge_light_domain",
		"_draw_forge_column"
	]:
		assert_false(secret_code.contains(rejected_marker),
				"传奇金光不得继续使用边界清晰的程序多边形")
	var aura_shader := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_env_scene6_forge_aura.gdshader")
	for marker: String in [
		"edge_noise", "vertical_fade", "source_bloom", "blend_add"
	]:
		assert_true(aura_shader.contains(marker))
	for rejected_marker: String in [
		"draw_colored_polygon(outer", "draw_colored_polygon(middle",
		"draw_colored_polygon(core"
	]:
		assert_false(secret_code.contains(rejected_marker),
				"金光不得退回同心实心梯形套娃")
	assert_false(secret_code.contains("_draw_forge_cracks"),
			"巨剑底部不得保留放射状金色条纹")
	assert_false(secret_code.contains("_draw_portal_ring"),
			"传奇氛围不得退回会读成水波涟漪的椭圆传送门")


func test_legendary_blade_clears_the_surface_and_hovers_in_open_air() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	await get_tree().process_frame
	var secrets := stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	secrets.legendary_rise_duration_sec = 0.04
	secrets.legendary_float_duration_sec = 0.28
	secrets.legendary_sink_duration_sec = 0.08
	secrets.reveal_cooldown_sec = 0.0
	secrets.legend_roll_override = 0.0
	for _click: int in secrets.clicks_per_reveal:
		secrets.register_molten_click(Vector2(1420.0, 936.0))
	await get_tree().create_timer(0.075).timeout
	var pocket := stage.get_node(
			"MagmaSecretFrontProps/LegendaryPocketRuntime") as Control
	var sprite := pocket.get_child(0) as Sprite2D
	var surface_local_y := pocket.size.y - 4.0
	var sprite_bottom := sprite.position.y \
			+ float(sprite.texture.get_height()) * sprite.scale.y * 0.5
	assert_eq(secrets.legendary_hover_clearance_px, 8.0)
	assert_lte(sprite_bottom, surface_local_y - 4.0,
			"传奇巨剑应完整离开岩浆并悬空，而不是仍泡在液面中")
	assert_gte(sprite_bottom, surface_local_y - 12.0,
			"传奇巨剑不能悬得过高，应贴近岩浆表面漂浮")
	await get_tree().create_timer(0.16).timeout
	assert_eq(secrets.active_secret_count(), 1,
			"传奇巨剑需保持较长的悬空展示阶段")


func test_magma_hit_mask_excludes_surface_shadow_and_dark_crust() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	add_child_autofree(stage)
	var interaction := stage.get_node("ClickInteraction") as Scene6ClickInteraction
	var lake := stage.get_node("MagmaLake") as ColorRect
	var found_molten := false
	var found_crust := false
	for local_y: int in range(32, int(lake.size.y), 4):
		for local_x: int in range(0, int(lake.size.x), 4):
			var canvas_point := lake.get_global_transform_with_canvas() \
					* Vector2(local_x, local_y)
			var molten := interaction._is_magma_lake_hit(canvas_point)
			found_molten = found_molten or molten
			found_crust = found_crust or not molten
			if found_molten and found_crust:
				break
		if found_molten and found_crust:
			break
	assert_true(found_molten)
	assert_true(found_crust)
	var guarded_point := lake.get_global_transform_with_canvas() \
			* Vector2(lake.size.x * 0.5, 4.0)
	assert_false(interaction._is_magma_lake_hit(guarded_point))


func _find_point_for_kind(
		interaction: Scene6ClickInteraction,
		interaction_kind: int,
		search_rect: Rect2,
		step_px: int
) -> Vector2:
	var start := Vector2i(search_rect.position)
	var end := Vector2i(search_rect.end)
	for y: int in range(start.y, end.y, step_px):
		for x: int in range(start.x, end.x, step_px):
			var point := Vector2(x, y)
			if interaction.get_interaction_kind_at_canvas_position(point) \
					== interaction_kind:
				return point
	return Vector2(-1.0, -1.0)
