extends GutTest

const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const BATTLE2_PATH := "res://src/ui/battle_screen2.tscn"
const RoundLabelOrnamentsScript := preload("res://src/ui/components/round_label_ornaments.gd")
const ItemSlotRowScript := preload("res://src/ui/components/item_slot_row.gd")
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
			screen.btn_longyuji_branch,
			screen.btn_split_big_wave,
			screen.btn_h24_discount,
		])
		for button: Button in bottom_buttons:
			var button_shadow := button.get_node_or_null("BottomShadow") as Control
			assert_not_null(button_shadow,
					"每个底部操作按钮都需要统一的下投影")
			if button_shadow != null:
				assert_gt(button_shadow.position.y, absf(button_shadow.position.x))
				assert_between(button_shadow.self_modulate.a, 0.35, 0.65)

		assert_not_null(screen._tip_skill_icon,
				"取消左下技能双钮后，统一提示框应承载头像技能图标")
		assert_eq(screen._tip_skill_icon.get_parent(), screen._tip_content,
				"技能图标应与文案共用同一说明框内容层")
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
				assert_almost_eq(reserve_row.icon_w / reserve_row.icon_h, 26.0 / 9.0, 0.01,
						"替补生命符号改为更接近主血条的细长比例")
				assert_eq(absf(reserve_row.icon_slant), 3.0,
						"替补生命符号斜率与缩小后的高度协调")
				assert_eq(reserve_row.font_size, 18,
						"替补生命数字提高一个视觉字号档位")
				assert_eq(reserve_row.gap_icon_num, 7.0,
						"生命符号与数字保留清晰呼吸距离")
				assert_eq(reserve_row.number_shadow_offset, Vector2(2.0, 3.0),
						"替补生命数字使用整数像素的右下定向阴影")
				assert_gt(reserve_row.number_shadow_color.a, reserve_row.bottom_shadow_color.a,
						"小字号数字阴影比图形投影更实，缩小后仍可读")
				assert_gt(
						reserve_row.bottom_shadow_offset.y,
						absf(reserve_row.bottom_shadow_offset.x))

		for side in [0, 1]:
			var frames: Array = screen.p1_frames if side == screen.PLAYER else screen.p2_frames
			var hp_rows: Array = screen.p1_frame_hp_rows if side == screen.PLAYER else screen.p2_frame_hp_rows
			for index in [1, 2]:
				assert_almost_eq(
						(hp_rows[index] as Control).get_global_rect().get_center().x,
						(frames[index] as Control).get_global_rect().get_center().x,
						0.01,
						"替补血量整组与对应头像严格水平居中")
	BattleSetup.reset()


func test_battle_utility_relayout_and_avatar_skill_tip_contract() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame

	assert_eq(screen.btn_confirm.position.x, 1772.0,
			"结束按钮保留原右侧 x 坐标")
	assert_almost_eq(screen.btn_confirm.get_global_rect().get_center().y, 970.0, 0.01,
			"结束按钮恢复到底部操作栏基线")
	assert_eq(screen.btn_codex.position, Vector2(1652.0, 46.0),
			"图鉴入口移动到结束按钮左侧")
	assert_almost_eq(screen.btn_codex.get_global_rect().get_center().y,
			screen.btn_confirm.get_global_rect().get_center().y, 0.01,
			"图鉴与结束按钮严格共用底部中心线")
	assert_almost_eq(screen.btn_confirm.get_global_rect().position.x
			- screen.btn_codex.get_global_rect().end.x, 12.0, 0.01,
			"右下工具组使用 12px 组内间距")
	assert_eq(screen.btn_switch.position, Vector2(30.0, 46.0),
			"切换模块占据左下安全边距")
	assert_eq(screen.p1_item_row.scale, Vector2.ONE * 0.92,
			"道具行比替补头像低一个视觉层级")
	assert_eq(screen.p2_item_row.scale, Vector2.ONE * 0.92,
			"敌方道具行与己方保持同档尺寸")
	assert_eq(ItemSlotRowScript.GAP, 12.0,
			"道具槽间距在缩放后仍保留清晰分组")
	assert_null(screen.get_node_or_null("SettingsButton"),
			"战斗界面不再显示设置按钮")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_not_null(screen.get_node_or_null("SettingsPanel"),
			"取消可见按钮后 ESC 仍能打开设置")
	screen.get_node("SettingsPanel").queue_free()
	screen.game_timer.paused = false

	screen._on_hero_skill_tip(screen.PLAYER, 0)
	assert_true(screen._tip_panel.visible,
			"悬停头像使用统一说明框")
	assert_true(screen._tip_skill_icon.visible,
			"头像技能说明展示英雄技能图标")
	assert_not_null(screen._tip_skill_icon.texture,
			"头像技能图标从 HeroData 资源加载")
	assert_gt(screen._tip_panel.global_position.y,
			(screen.p1_frame_hp_rows[1] as Control).get_global_rect().end.y,
			"头像技能说明下移到替补血量行下方")
	var active_hero: HeroData = screen.battle.heroes[screen.PLAYER][
			screen.battle.active_index[screen.PLAYER]]
	var parsed_skill_text: String = screen._tip_rich.get_parsed_text().replace("\u2060", "")
	assert_true(parsed_skill_text.contains(tr(active_hero.skill_detail)),
			"说明框只保留对应英雄的技能效果正文")
	if active_hero.skill_description != active_hero.skill_detail:
		assert_false(parsed_skill_text.contains(tr(active_hero.skill_description)),
				"头像技能说明不再重复顶部技能名")
	var item_tip: String = screen._item_slot_tip(0)
	assert_false(item_tip.begins_with("【") or item_tip.contains("】\n"),
			"已有道具名称不再显示书名括号")
	screen._on_item_slot_hovered(0)
	assert_true(screen._tip_item_header.visible,
			"具名道具说明显示图标与名称顶部行")
	assert_almost_eq(screen._tip_item_icon.size.x, 32.0, 0.01,
			"顶部只保留整像素尺寸的道具图标，避免缩放边框破损")
	assert_eq(screen._tip_item_icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"道具图标使用点采样保持像素边缘")
	assert_almost_eq(screen._tip_item_title.position.x
			- screen._tip_item_icon.get_rect().end.x, 6.0, 0.01,
			"道具名紧跟图标并保留最小可读间距")
	assert_almost_eq(screen._tip_rich.offset_left,
			screen._tip_item_header.position.x, 0.01,
			"下方正文最左侧与道具图标最左侧严格对齐")
	var item_content_width: float = screen.tip_size_item.x - screen.tip_padding_horizontal_l * 2.0
	assert_almost_eq(screen._tip_item_header.position.x,
			item_content_width - screen._tip_item_header.get_rect().end.x, 1.0,
			"图标、名称与正文共用的内容列在说明框中整体居中")
	assert_gt(screen._tip_rich.offset_top,
			screen._tip_item_header.position.y + screen._tip_item_icon.size.y,
			"正文位于顶部道具行下方")
	assert_eq(screen._tip_panel.size, screen.tip_size_item,
			"具名道具使用独立高度，避免新增顶部行挤压说明正文")
	assert_eq(screen.item_tip_vertical_lift, 12.0,
			"道具标题整体上移量暴露为可手调参数")
	assert_eq(screen.item_tip_title_body_gap, 24,
			"道具名称与正文间隔遵循场景中的当前手调值")
	var gap_property: Dictionary = {}
	for property: Dictionary in screen.get_property_list():
		if property.get("name", "") == "item_tip_title_body_gap":
			gap_property = property
			break
	assert_true(String(gap_property.get("hint_string", "")).contains("64"),
			"道具名称与正文间距的 Inspector 上限扩展到 64")
	screen._set_l_tip_text("点击抽取道具", screen.TipContentKind.ITEM)
	assert_false(screen._tip_item_header.visible,
			"空槽状态不显示无意义的道具框顶部行")
	assert_eq(screen._tip_rich.vertical_alignment, VERTICAL_ALIGNMENT_CENTER,
			"空槽提示继续在整张说明纸中居中")
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
