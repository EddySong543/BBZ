extends GutTest

const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const BATTLE2_PATH := "res://src/ui/battle_screen2.tscn"
const RoundLabelOrnamentsScript := preload("res://src/ui/components/round_label_ornaments.gd")
const DARK_SCENE_COLOR := Color("#f2e8cc")
const WARNING_COLORS: Array[Color] = [
	Color("#f1c21b"),
	Color("#ff832b"),
	Color("#da1e28"),
]


func test_scene_variants_share_the_beige_countdown_palette() -> void:
	var screen1 := (load(BATTLE1_PATH) as PackedScene).instantiate()
	var screen2 := (load(BATTLE2_PATH) as PackedScene).instantiate()
	assert_true(screen1.countdown_normal_color.is_equal_approx(DARK_SCENE_COLOR))
	assert_eq(screen1.countdown_outline_size, 4)
	assert_eq(screen1.countdown_ornament_underlay_width, 3.0)
	assert_true(screen2.countdown_normal_color.is_equal_approx(DARK_SCENE_COLOR))
	assert_eq(screen2.countdown_outline_size, 4)
	assert_true(screen2.countdown_ornament_color.is_equal_approx(DARK_SCENE_COLOR))
	assert_eq(screen2.countdown_ornament_underlay_width, 3.0)
	screen1.free()
	screen2.free()


func test_top_countdown_uses_the_turn_start_directional_shadow() -> void:
	BattleSetup.reset()
	for scene_path in [BATTLE1_PATH, BATTLE2_PATH]:
		var screen := (load(scene_path) as PackedScene).instantiate()
		add_child_autofree(screen)
		await get_tree().process_frame
		assert_true(
			screen.timer_label.get_theme_color("font_shadow_color").is_equal_approx(
				Color(0.0, 0.0, 0.0, 0.60)),
			"顶部倒计时应沿用回合开始的深色定向投影")
		assert_eq(screen.timer_label.get_theme_constant("shadow_offset_x"), 3)
		assert_eq(screen.timer_label.get_theme_constant("shadow_offset_y"), 3)
	BattleSetup.reset()


func test_battle_avatar_frames_and_bottom_buttons_use_directional_shadows() -> void:
	BattleSetup.reset()
	for scene_path in [BATTLE1_PATH, BATTLE2_PATH]:
		var screen := (load(scene_path) as PackedScene).instantiate()
		add_child_autofree(screen)
		await get_tree().process_frame

		for frame: HeroFrame in screen.p1_frames + screen.p2_frames:
			var frame_shadow := frame.get_node_or_null("BottomShadow") as Control
			assert_not_null(frame_shadow,
					"顶部头像框需要与回合开始同方向的下投影")
			if frame_shadow != null:
				assert_gt(frame_shadow.position.y, absf(frame_shadow.position.x),
						"头像框投影应以向下落为主，不能变成四周描边")
				assert_lte(frame_shadow.position.y, 4.0,
						"头像框投影需贴近主体，不能与头像框脱节")
				assert_between(frame_shadow.self_modulate.a, 0.30, 0.45,
						"头像框投影应比底部按钮投影更柔和")
				assert_lt(
						frame_shadow.get_index(),
						frame.get_node("DiamondFrame").get_index(),
						"投影必须位于头像框主体之后")

		var bottom_buttons: Array[Button] = screen.action_btn_list.duplicate()
		bottom_buttons.append_array([
			screen.btn_confirm,
			screen.btn_codex,
			screen.btn_jifeng,
		])
		for button: Button in bottom_buttons:
			var button_shadow := button.get_node_or_null("BottomShadow") as Control
			assert_not_null(button_shadow,
					"每个底部操作按钮都需要统一的下投影")
			if button_shadow != null:
				assert_gt(button_shadow.position.y, absf(button_shadow.position.x))
				assert_between(button_shadow.self_modulate.a, 0.35, 0.65)

		var info_button_count := 0
		for child in screen._skill_info.get_children():
			if child is Button:
				info_button_count += 1
				assert_not_null(child.get_node_or_null("BottomShadow"),
						"左下技能情报按钮也属于底部按钮系统")
		assert_eq(info_button_count, 2)
	BattleSetup.reset()


func test_battle_hud_rows_use_shape_fitted_directional_shadows() -> void:
	BattleSetup.reset()
	for scene_path in [BATTLE1_PATH, BATTLE2_PATH]:
		var screen := (load(scene_path) as PackedScene).instantiate()
		add_child_autofree(screen)
		await get_tree().process_frame

		for health_row in [screen.p1_heart_row, screen.p2_heart_row]:
			assert_true(health_row.bottom_shadow_enabled)
			assert_gt(health_row.bottom_shadow_offset.y, absf(health_row.bottom_shadow_offset.x))
			assert_between(health_row.bottom_shadow_color.a, 0.25, 0.40)

		for energy_row in [screen.p1_coin_row, screen.p2_coin_row]:
			assert_true(energy_row.bottom_shadow_enabled)
			assert_gt(energy_row.bottom_shadow_offset.y, absf(energy_row.bottom_shadow_offset.x))
			assert_between(energy_row.bottom_shadow_color.a, 0.25, 0.40)

		for item_row: ItemSlotRow in [screen.p1_item_row, screen.p2_item_row]:
			assert_true(item_row.bottom_shadow_enabled)
			assert_eq(item_row._bottom_shadows.size(), 3)
			for shadow: TextureRect in item_row._bottom_shadows:
				assert_true(shadow.visible)
				assert_eq(shadow.texture, ItemSlotRow.ITEM_FRAME_TEX)
				assert_gt(shadow.position.y, ItemSlotRow.FRAME_ART_OFFSET.y)
				assert_between(shadow.self_modulate.a, 0.25, 0.40)

		for reserve_row in screen.p1_frame_hp_rows + screen.p2_frame_hp_rows:
			if reserve_row != null:
				assert_true(reserve_row.bottom_shadow_enabled)
				assert_gt(
						reserve_row.bottom_shadow_offset.y,
						absf(reserve_row.bottom_shadow_offset.x))
	BattleSetup.reset()


func test_last_three_seconds_use_progressive_alert_colors_and_line_fill() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE2_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var ornaments: RoundLabelOrnamentsScript = screen.timer_label.get_node("RoundLabelOrnaments")

	for index in WARNING_COLORS.size():
		var seconds_left := 3 - index
		screen.timer_seconds = seconds_left
		screen._update_timer_label()
		assert_eq(
			screen.timer_label.get_theme_color("font_color"),
			WARNING_COLORS[index],
			"最后 %d 秒使用对应的 Carbon 警告色" % seconds_left)
		assert_almost_eq(
			ornaments.warning_target,
			float(index + 1) / 3.0,
			0.001,
			"装饰线警告覆盖应随倒计时逐段向外推进")

	screen.timer_seconds = 4
	screen._update_timer_label()
	assert_true(
		screen.timer_label.get_theme_color("font_color").is_equal_approx(DARK_SCENE_COLOR))
	assert_eq(ornaments.warning_target, 0.0)
	BattleSetup.reset()
