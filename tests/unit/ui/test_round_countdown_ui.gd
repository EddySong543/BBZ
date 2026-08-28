extends GutTest


func _justified_tip_caret_x(
		screen: Control, line_range: Vector2i, caret_index: int) -> float:
	var parsed_text: String = screen._tip_rich.get_parsed_text()
	var text_line := TextLine.new()
	text_line.direction = TextServer.DIRECTION_AUTO
	text_line.alignment = HORIZONTAL_ALIGNMENT_FILL
	text_line.flags = TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND
	text_line.width = screen._tip_rich.size.x
	var line_end := line_range.y
	var cursor := line_range.x
	while cursor < line_end:
		var is_keyword: bool = screen._tip_character_is_keyword(cursor)
		var run_end := cursor + 1
		while run_end < line_end \
				and screen._tip_character_is_keyword(run_end) == is_keyword:
			run_end += 1
		var run_font: Font = screen._tip_effect_bold_font if is_keyword \
				else screen._tip_rich.get_theme_font("normal_font")
		text_line.add_string(
				parsed_text.substr(cursor, run_end - cursor),
				run_font, screen.tip_font_size_l, "zh_CN")
		cursor = run_end
	var caret_info: Dictionary = TextServerManager.get_primary_interface().shaped_text_get_carets(
			text_line.get_rid(), caret_index - line_range.x)
	var leading_caret: Rect2 = caret_info.get("leading_rect", Rect2())
	var trailing_caret: Rect2 = caret_info.get("trailing_rect", Rect2())
	return maxf(leading_caret.position.x, trailing_caret.position.x)

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
			screen.btn_backpack,
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

	assert_almost_eq(screen.timer_label.get_global_rect().get_center().x, 960.0, 0.01,
			"顶部倒计时严格落在 1920 画面中轴")
	for index in [1, 2]:
		var p1_center := (screen.p1_frames[index] as Control).get_global_rect().get_center().x
		var p2_center := (screen.p2_frames[index] as Control).get_global_rect().get_center().x
		assert_almost_eq(p1_center + p2_center, 1920.0, 0.01,
				"双方对应替补头像以画面中轴严格镜像")

	assert_eq(screen.btn_confirm.position.x, 1772.0,
			"结束按钮保留原右侧 x 坐标")
	assert_almost_eq(screen.btn_confirm.get_global_rect().get_center().y, 970.0, 0.01,
			"结束按钮回到右下工具行")
	assert_null(screen.get_node_or_null("Buttons/BtnCodex"),
			"战斗 HUD 不再生成图鉴入口")
	assert_eq(screen.btn_backpack.position, Vector2(1652.0, 46.0),
			"背包入口保留在结束按钮左侧")
	assert_almost_eq(screen.btn_backpack.get_global_rect().get_center().y,
			screen.btn_confirm.get_global_rect().get_center().y, 0.01,
			"背包与结束按钮严格共用底部中心线")
	assert_almost_eq(screen.btn_confirm.get_global_rect().position.x
			- screen.btn_backpack.get_global_rect().end.x, 12.0, 0.01,
			"右下背包与结束按钮使用 12px 组内间距")
	assert_not_null(screen.btn_backpack.get_node_or_null("BackpackIcon"),
			"战斗背包入口使用已导入的背包图标")
	screen.btn_backpack.pressed.emit()
	await get_tree().process_frame
	var backpack_overlay := screen.get_node_or_null("BackpackOverlay") as Control
	assert_not_null(backpack_overlay, "点击战斗背包入口实例化共享背包浮层")
	assert_true(backpack_overlay.visible, "战斗背包入口会呼出背包")
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
	assert_almost_eq(screen._tip_effect_bold_font.variation_embolden,
			0.32, 0.001,
			"战斗说明关键词同步采用克制的小幅加粗")
	var h06_frame_index := -1
	for frame_index: int in screen.p1_frame_slots.size():
		var slot: int = screen.p1_frame_slots[frame_index]
		if (screen.battle.heroes[screen.PLAYER][slot] as HeroData).hero_id == "h06":
			h06_frame_index = frame_index
			break
	assert_gte(h06_frame_index, 0)
	if h06_frame_index >= 0:
		screen._on_hero_skill_tip(screen.PLAYER, h06_frame_index)
		await get_tree().process_frame
		var concise_h06: String = screen._tip_rich.get_parsed_text().replace("\u2060", "")
		assert_true(concise_h06.contains("1层毒素"))
		assert_false(concise_h06.contains("毒素："),
				"战斗技能说明与英雄图鉴一致，不重复效果百科释义")
		assert_gt((screen._tip_keyword_sparks as Array).size(), 0,
				"战斗说明中的效果词同步显示右上角星芒")
		assert_true(concise_h06.contains(EffectTextFormatter.KEYWORD_TRAILING_SPACER_GLYPH),
				"战斗悬停说明必须为覆盖绘制的星芒保留同行占位")
		var spacer_width: float = screen._tip_rich.get_theme_font("normal_font").get_string_size(
				EffectTextFormatter.KEYWORD_TRAILING_SPACER,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, screen.tip_font_size_l).x
		assert_gte(spacer_width,
				EffectKeywordSpark.MARK_SIZE.x + EffectTextFormatter.KEYWORD_SPARK_OFFSET.x,
				"战斗悬停的星芒占位必须覆盖完整角标宽度")
	var item_tip: String = screen._item_slot_tip(0)
	assert_false(item_tip.begins_with("【") or item_tip.contains("】\n"),
			"已有道具名称不再显示书名括号")
	screen._on_item_slot_hovered(0)
	await get_tree().process_frame
	assert_true(screen._tip_item_header.visible,
			"具名道具说明显示图标与名称顶部行")
	assert_eq(screen.tip_font_size_s, 17,
			"五个基础动作短说明字号回退到 17px")
	assert_eq(screen._tip_label.get_theme_font_size("font_size"), 17,
			"基础动作说明实际使用回退后的字号")
	assert_eq(screen.tip_optical_center_shift_s, 0.0,
			"底部按钮 S 框保留几何中心，不继承道具补偿")
	assert_eq(screen.tip_optical_center_shift_l, 0.0,
			"普通技能 L 框保留几何中心")
	assert_eq(screen.tip_optical_center_shift_avatar_skill, 0.0,
			"顶部头像技能说明恢复几何中心")
	assert_eq(screen.tip_optical_center_shift_item, 0.0,
			"道具标题与正文恢复严格几何中心，不再推动整张内容层")
	assert_almost_eq(screen._tip_stylebox.content_margin_left
			- screen._tip_stylebox.content_margin_right,
			0.0, 0.01, "道具 M 框左右内容边距严格相等")
	assert_almost_eq(screen._tip_content.get_global_rect().get_center().x
			- screen._tip_panel.get_global_rect().get_center().x,
			0.0, 0.01, "道具 M 的实际内容矩形严格位于框中心")
	screen._set_tip_content_margins(screen.TipFormat.S, screen.TipContentKind.PLAIN)
	assert_eq(screen._tip_stylebox.content_margin_left,
			screen._tip_stylebox.content_margin_right,
			"底部 S 框左右边距恢复对称")
	screen._set_tip_content_margins(screen.TipFormat.L,
			screen.TipContentKind.AVATAR_SKILL)
	assert_eq(screen._tip_stylebox.content_margin_left, 18.0,
			"头像技能说明与左边框保持固定安全距离")
	assert_eq(screen._tip_stylebox.content_margin_right, 18.0,
			"头像技能说明与右边框保持固定安全距离")
	assert_eq(screen._tip_stylebox.content_margin_top, 10.0)
	assert_eq(screen._tip_stylebox.content_margin_bottom, 10.0)
	screen._on_hero_skill_tip(screen.PLAYER, 0)
	await get_tree().process_frame
	assert_eq(screen._tip_rich.get_theme_constant("line_separation"),
			screen.tip_line_spacing,
			"头像技能说明使用 S/M/L 共用行距")
	assert_almost_eq(screen._tip_panel.get_global_rect().end.x
			- screen._tip_rich.get_global_rect().end.x,
			screen.tip_padding_horizontal_avatar_skill, 0.51,
			"技能正文右缘不能进入固定边框安全区")
	# 恢复具名道具状态，后续继续验证道具专用排版。
	screen._on_item_slot_hovered(0)
	await get_tree().process_frame
	screen._set_tip_content_margins(screen.TipFormat.M, screen.TipContentKind.ITEM)
	assert_eq(screen._tip_rich.get_theme_constant("line_separation"),
			screen.tip_line_spacing,
			"道具 M 框与技能 L 框保持完全相同行距")
	var big_defend_tip: String = screen._action_tip(ActionDef.Action.BIG_DEFEND)
	assert_eq(big_defend_tip, "抵挡「波」、「大波」",
			"大防 S 框完整回退到先前括号文案")
	var battle_item_material := screen.p1_item_row._cell_mats[0] as ShaderMaterial
	assert_eq(float(battle_item_material.get_shader_parameter("vertical_gradient")), 1.0,
			"战斗普通道具格回退为静态纵向渐变")
	var battle_icon_shadow := screen.p1_item_row._icon_shadows[0] as TextureRect
	assert_true(battle_icon_shadow.visible, "战斗道具美术具备落在格底上的 alpha 投影")
	assert_eq(battle_icon_shadow.texture, screen.p1_item_row._icons[0].texture,
			"图案投影严格复制当前道具纹理")
	assert_lt(battle_icon_shadow.get_index(), screen.p1_item_row._tex_frames[0].get_index(),
			"图案投影位于格底上方、金属框下方")
	assert_almost_eq(screen._tip_item_icon.size.x, 32.0, 0.01,
			"顶部只保留整像素尺寸的道具图标，避免缩放边框破损")
	assert_eq(screen._tip_item_icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"道具图标使用点采样保持像素边缘")
	var icon_visual_gap_rect: Rect2 = screen._item_tip_icon_visual_rect(
			screen._tip_item_icon.texture)
	assert_almost_eq(screen._tip_item_title.position.x
			- (screen._tip_item_icon.position.x + icon_visual_gap_rect.end.x), 8.0, 0.51,
			"道具名紧跟图标真实 alpha 边界并保留最小可读间距")
	var item_content_width: float = screen.tip_size_m.x - screen.tip_padding_horizontal_m * 2.0
	assert_almost_eq(screen._tip_item_header.position.x + screen._tip_item_header.size.x * 0.5,
			item_content_width * 0.5, 0.51,
			"顶部图标与名称使用固定且居中的标题轨道")
	var icon_visual: Rect2 = screen._item_tip_icon_visual_rect(screen._tip_item_icon.texture)
	var visible_left: float = screen._tip_item_icon.position.x + icon_visual.position.x
	var title_font: Font = screen._tip_item_title.get_theme_font("font")
	var title_width: float = title_font.get_string_size(
			screen._tip_item_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			screen._tip_item_title.get_theme_font_size("font_size")).x
	var visible_right: float = screen._tip_item_title.position.x + title_width
	assert_almost_eq((visible_left + visible_right) * 0.5,
			screen._tip_item_header.size.x * 0.5, 0.75,
			"按图标真实 alpha 边界与标题字宽居中，不再只把空容器数学居中")
	assert_eq(screen._tip_rich.offset_left, 8.0,
			"正文恢复上轮前的 8px 左起笔位，不能继续贴向纸框左侧")
	assert_eq(screen._tip_rich.offset_right, -8.0,
			"右侧使用同等 8px 安全位，保持标题与正文同轴")
	assert_almost_eq(screen._tip_rich.size.x,
			item_content_width - 16.0, 0.51,
			"正文使用左右各8px的固定对称列")
	assert_true(screen._item_slot_tip(0).ends_with("。"),
			"战斗道具说明恢复完整句号")
	assert_eq(screen._tip_item_title.get_theme_font_size("font_size"), 17,
			"道具名只保留一级字号差，避免重新退化为粗重标题方案")
	var item_title_font := screen._tip_item_title.get_theme_font("font") as FontVariation
	assert_not_null(item_title_font)
	assert_almost_eq(item_title_font.variation_embolden, 0.25, 0.01,
			"标题字重只作辅助，主要层级由标题轨道和分隔建立")
	assert_almost_eq(screen._tip_item_header.position.y, 2.0, 0.01,
			"标题行贴近内容区顶部，不再造成整体下坠")
	assert_true(screen._tip_item_rule.visible,
			"具名道具显示克制分隔线，稳定区分标题与正文")
	assert_eq(screen._tip_item_rule.size.y, screen.ITEM_TIP_RULE_HEIGHT,
			"分隔线使用稳定的像素刻线高度")
	assert_eq(screen._tip_item_rule.get_script().resource_path,
			"res://src/ui/components/item_tip_pixel_divider.gd",
			"分隔线使用水平主线和两端短竖线，形成横向工字结构")
	assert_eq(screen._tip_item_rule.get_child_count(), 0,
			"像素刻线由单一绘制组件生成，不堆叠零散 ColorRect")
	var divider_geometry: Dictionary = screen._tip_item_rule.debug_geometry()
	var divider_line := divider_geometry["line"] as Rect2
	var divider_highlight := divider_geometry["highlight"] as Rect2
	var divider_left_cap := divider_geometry["left_cap"] as Rect2
	var divider_right_cap := divider_geometry["right_cap"] as Rect2
	assert_eq(divider_line.size.y, 1.0,
			"终版主线收为一行像素阴刻，不再形成第二层粗边框")
	assert_eq(divider_highlight.size.y, 1.0,
			"阴线下只跟一行纸色亮边，形成压痕而不是墨条")
	assert_eq(divider_highlight.position.y, divider_line.end.y,
			"亮边必须紧邻阴线，不能拆成装饰性双横线")
	assert_eq(divider_left_cap.size.x, 1.0,
			"端帽同步收为一像素笔画")
	assert_lte(divider_left_cap.size.y, 4.0,
			"左端竖线只作简短收口，不能形成沉重边框")
	assert_eq(divider_left_cap.size, divider_right_cap.size,
			"两端短竖线严格对称")
	var divider_shadow := Color("8B765D")
	var divider_paper_light := Color("E3CAA2")
	assert_true(screen._tip_item_rule.shadow_color.is_equal_approx(divider_shadow),
			"压痕阴线沿用书页暖褐中阶")
	assert_true(screen._tip_item_rule.highlight_color.is_equal_approx(divider_paper_light),
			"压痕亮边使用接近纸面的暖亮色，不再以深色抢标题")
	var tooltip_frame_image: Image = preload(
			"res://assets/ui/ui_tooltip_book_pixel.png").get_image()
	for corner_sample: Vector2i in [
			Vector2i(6, 1), Vector2i(172, 1), Vector2i(1, 37), Vector2i(186, 37)]:
		assert_eq(tooltip_frame_image.get_pixelv(corner_sample), Color.BLACK,
				"四角角套仍保留源素材纯黑，不因分割线降深而改色")
	assert_gt(screen._tip_item_rule.shadow_color.get_luminance(), Color.BLACK.get_luminance(),
			"分割线必须明显浅于四角角套的纯黑")
	assert_gt(screen._tip_item_rule.shadow_color.get_luminance(),
			Color(0.27, 0.21, 0.14).get_luminance(),
			"分割线必须浅于正文墨色，把视觉主导权还给道具名和正文")
	assert_lt(screen._tip_item_rule.shadow_color.get_luminance(),
			Color("D7BD99").get_luminance(),
			"分割线仍须深于纸张底色，不能淡到失去分区作用")
	assert_gt(screen._tip_item_rule.highlight_color.get_luminance(),
			Color("D7BD99").get_luminance(),
			"亮边必须比纸面略亮，才能读成浅压痕")
	assert_almost_eq(divider_left_cap.get_center().y,
			(divider_line.position.y + divider_highlight.end.y) * 0.5, 0.01,
			"端帽只包住两像素压痕，不引入上下起伏")
	assert_gte(divider_line.size.x, float(screen._tip_rich.get_line_width(0)),
			"分割线宽度至少覆盖下方正文任意一行的实际宽度")
	assert_almost_eq(divider_line.size.x, screen._tip_item_rule.size.x, 0.01,
			"横向工字线占满正文最大排版轨道，建立稳定的标题分区比例")
	assert_eq(screen.item_tip_rule_vertical_offset, -2.0,
			"分割线默认独立上移 2px")
	var unshifted_rule_top: float = (
			screen._tip_item_header.position.y + screen.ITEM_TIP_ICON_SIZE
			+ screen.ITEM_TIP_HEADER_RULE_GAP)
	assert_almost_eq(screen._tip_item_rule.position.y,
			unshifted_rule_top + screen.item_tip_rule_vertical_offset, 0.01,
			"负偏移只将分割线向上移动")
	assert_almost_eq(screen._tip_rich.offset_top,
			unshifted_rule_top + screen.ITEM_TIP_RULE_HEIGHT
					+ screen.item_tip_title_body_gap, 0.01,
			"独立移动分割线不挤压正文排版")
	assert_eq(screen._tip_panel.size, screen.tip_size_m,
			"具名道具使用 222x144 加高 M 框，宽度保持不变")
	assert_eq(screen.item_tip_vertical_lift, 0.0,
			"固定轴线默认不再叠加历史上移补偿")
	assert_eq(screen.item_tip_title_body_gap, 8,
			"道具名称与正文保持一个短呼吸位")
	var gap_property: Dictionary = {}
	for property: Dictionary in screen.get_property_list():
		if property.get("name", "") == "item_tip_title_body_gap":
			gap_property = property
			break
	assert_true(String(gap_property.get("hint_string", "")).contains("64"),
			"道具名称与正文间距的 Inspector 上限扩展到 64")
	screen._set_l_tip_text("短名\n短说明", screen.TipContentKind.ITEM)
	assert_almost_eq(screen._tip_item_header.position.x,
			screen.ITEM_TIP_COLUMN_INSET, 0.01,
			"短道具名继续使用固定标题轨道")
	assert_almost_eq(screen._tip_rich.offset_left,
			8.0, 0.01,
			"短说明也沿用固定左对齐列，不再按文字长度缩成窄栏")
	assert_almost_eq(screen._tip_rich.get_rect().end.x,
			screen._tip_content.size.x - 8.0, 0.51,
			"短说明的右缘保留与左侧一致的 8px 安全位")
	screen._set_l_tip_text("很长的道具名称\n这是一段会自动换行的较长道具说明文字",
			screen.TipContentKind.ITEM)
	assert_almost_eq(screen._tip_item_header.position.x,
			screen.ITEM_TIP_COLUMN_INSET, 0.01,
			"长道具名不会推动标题轨道")
	assert_almost_eq(screen._tip_rich.get_rect().end.x,
			screen._tip_content.size.x - 8.0, 0.51,
			"长说明换行后仍使用到右侧安全边界")
	screen._set_l_tip_text(
			"排版测试\n本回合内，我方下一次攻击造成的伤害增加2点，或使敌方下一次攻击造成的伤害增加2点。",
			screen.TipContentKind.ITEM)
	await get_tree().process_frame
	assert_eq(screen._tip_keyword_alignment, HORIZONTAL_ALIGNMENT_FILL,
			"中文书页正文使用两端对齐，不再靠反复试边距掩盖行尾空字格")
	var protected_item_text: String = screen._tip_rich.get_parsed_text()
	assert_lte(protected_item_text.count(EffectTextFormatter.WORD_JOINER), 8,
			"道具正文只保护禁则标点，不得重新把大量普通词锁成不可断片段")
	for line_index: int in maxi(screen._tip_rich.get_line_count() - 1, 0):
		var unused_width: float = (
				screen._tip_rich.size.x - screen._tip_rich.get_line_width(line_index))
		assert_lt(absf(unused_width), 1.1,
				"两端对齐后的非末行必须真正抵达右侧正文边界")
	var sample_last_line: int = screen._tip_rich.get_line_count() - 1
	assert_lt(screen._tip_rich.get_line_width(sample_last_line),
			screen._tip_rich.size.x - 1.0,
			"两端对齐只作用于非末行，末行仍保持自然左齐")
	# 用全部正式道具文案守住这条排版契约，避免只修一条示例后再次复发。
	for item: ItemData in ItemCatalog.all():
		screen._clear_tip_keyword_sparks(true)
		screen._set_l_tip_text(
				"%s\n%s" % [item.item_name, item.description],
				screen.TipContentKind.ITEM, item)
		await get_tree().process_frame
		for keyword_range: Vector2i in screen._tip_keyword_ranges:
			assert_eq(screen._tip_rich.get_character_line(keyword_range.x),
					screen._tip_rich.get_character_line(
							keyword_range.x + keyword_range.y - 1),
					"正式道具 %s 的效果关键词不可拆到两行" % item.item_id)
		var parsed_item_text: String = screen._tip_rich.get_parsed_text()
		for line_index: int in screen._tip_rich.get_line_count():
			var line_range: Vector2i = screen._tip_rich.get_line_range(line_index)
			var line_text := parsed_item_text.substr(
					line_range.x, line_range.y - line_range.x)
			assert_false(EffectTextFormatter.line_starts_with_forbidden(line_text),
					"正式道具 %s 的正文行首不得出现闭合符号" % item.item_id)
			assert_false(EffectTextFormatter.line_ends_with_forbidden(line_text),
					"正式道具 %s 的正文行尾不得留下开放符号" % item.item_id)
		for line_index: int in maxi(screen._tip_rich.get_line_count() - 1, 0):
			var unused_width: float = (
					screen._tip_rich.size.x - screen._tip_rich.get_line_width(line_index))
			assert_lt(absf(unused_width), 1.1,
					"正式道具 %s 的非末行没有填满右侧" % item.item_id)
	var keyword_item := ItemCatalog.make("t1_jiedu_yaoshui")
	screen._clear_tip_keyword_sparks(true)
	screen._set_l_tip_text(
			"%s\n%s" % [keyword_item.item_name, keyword_item.description],
			screen.TipContentKind.ITEM, keyword_item)
	await get_tree().process_frame
	var filled_keyword_count := 0
	for range_index: int in screen._tip_keyword_ranges.size():
		var keyword_range: Vector2i = screen._tip_keyword_ranges[range_index]
		var line_index: int = screen._tip_rich.get_character_line(keyword_range.x)
		if screen._tip_rich.get_line_width(line_index) < screen._tip_rich.size.x - 1.0:
			continue
		filled_keyword_count += 1
		var expected_caret_x := _justified_tip_caret_x(
				screen, screen._tip_rich.get_line_range(line_index),
				keyword_range.x + keyword_range.y)
		assert_gt(expected_caret_x, 12.0,
				"TextServer 必须返回真实字符光标，不能因字典键错误回退到零点")
		assert_lte(expected_caret_x, screen._tip_rich.size.x,
				"关键词末端光标必须落在正文列内")
		var spark: Control = screen._tip_keyword_sparks[range_index]
		assert_almost_eq(spark.position.x,
				roundf(expected_caret_x + EffectTextFormatter.KEYWORD_SPARK_OFFSET.x),
				0.51,
				"两端对齐分摊字距后，星芒仍必须贴住关键词末字")
	assert_gt(filled_keyword_count, 0,
			"回归文案必须覆盖至少一个处于两端对齐行的效果关键词")
	screen._set_l_tip_text("我方获得1点能量", screen.TipContentKind.SKILL)
	assert_true(screen._tip_rich.get_parsed_text().contains("\u2060"),
			"技能说明仍保留原有的高频规则词保护，这次只修正道具正文")
	screen._set_l_tip_text("点击抽取道具", screen.TipContentKind.ITEM)
	assert_false(screen._tip_item_header.visible,
			"空槽状态不显示无意义的道具框顶部行")
	assert_false(screen._tip_item_rule.visible,
			"空槽状态不残留具名道具的标题分隔线")
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
