extends GutTest

func before_each() -> void:
	BattleSetup.reset()


func after_each() -> void:
	BattleSetup.reset()


func _make_screen():
	var packed := load("res://src/ui/battle_screen1.tscn") as PackedScene
	var screen = packed.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func test_switch_resolution_bubble_reuses_formal_animated_icon() -> void:
	var screen = await _make_screen()
	var bubble := screen._spawn_action_circle(0, ActionDef.Action.SWITCH) as Control
	var icon := bubble.get_node_or_null("ActionIcon") as HoverIcon
	assert_not_null(icon, "切换结算气泡不再显示文字占位，而是正式 switch button 图标")
	assert_eq(icon.sheet.resource_path, "res://assets/ui/icons/switch_hover_sheet.png")
	assert_eq(icon.playback_frames, PackedInt32Array([0, 1, 2]),
			"结算气泡与切换按钮共用排除坏帧后的播放序列")
	assert_true(icon.auto_play, "结算揭示期间 switch 图标自动播放，不依赖鼠标悬停")
	assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"结算气泡继续保持像素图标最近邻采样")
	var has_label := false
	for child: Node in bubble.get_children():
		has_label = has_label or child is Label
	assert_false(has_label, "切换气泡彻底移除“切换”文字回退")


func test_resolution_bubble_anchor_tracks_character_art_and_stays_on_canvas() -> void:
	var screen = await _make_screen()
	assert_eq(screen.action_bubble_head_ratio, 0.21,
			"气泡纵向锚点只回收一个小步，避免重新压到角色头部")
	assert_eq(screen.action_bubble_side_ratio, 0.23,
			"气泡侧向距离由 0.25 收回至 0.23")
	var cd: CharacterDisplay = screen.p1_char_display
	var before: Vector2 = screen._action_bubble_target_position(0, screen.action_bubble_size)
	var sprite_rect: Rect2 = screen._character_sprite_rect(cd)
	# 只保护头像真正占据的中央核心；旧测试把立绘顶部 32% 全算禁区，连透明留白也会
	# 把气泡推远，无法区分“接近角色”和“压到角色”。
	var head_exclusion := Rect2(
		Vector2(sprite_rect.get_center().x - sprite_rect.size.x * 0.10, sprite_rect.position.y),
		Vector2(sprite_rect.size.x * 0.20, sprite_rect.size.y * 0.36))
	assert_false(Rect2(before, Vector2.ONE * screen.action_bubble_size).intersects(head_exclusion),
			"默认气泡在角色头部排除区外，不再与立绘重合")
	cd.sprite_offset += Vector2(32.0, -24.0)
	var moved: Vector2 = screen._action_bubble_target_position(0, screen.action_bubble_size)
	assert_gt(moved.x, before.x, "立绘向右调位时，结算气泡跟随实际角色显示区域")
	assert_lt(moved.y, before.y, "立绘向上调位时，结算气泡跟随实际角色显示区域")
	cd.sprite_offset = Vector2(-2000.0, -2000.0)
	var clamped: Vector2 = screen._action_bubble_target_position(0, screen.action_bubble_size)
	assert_gte(clamped.x, screen.action_bubble_safe_margin,
			"极端角色偏移下气泡仍受左侧安全边界保护")
	assert_gte(clamped.y, screen.action_bubble_safe_margin,
			"极端角色偏移下气泡仍受顶部安全边界保护")


func test_all_basic_actions_share_the_same_roomier_s_tooltip() -> void:
	var screen = await _make_screen()
	assert_eq(screen.TipFormat.size(), 3,
			"说明框只保留职责明确的 S/M/L 三种尺寸")
	assert_true(screen.TipFormat.has("M"), "道具说明正式使用 M 框，不再伪装成 L 框")
	assert_eq(screen.tip_size_s, Vector2(156.0, 76.0))
	for action: int in [
			ActionDef.Action.CHARGE, ActionDef.Action.ATTACK,
			ActionDef.Action.BIG_ATTACK, ActionDef.Action.DEFEND,
			ActionDef.Action.BIG_DEFEND]:
		screen._show_tip_at(Rect2(700.0, 800.0, 80.0, 80.0),
				screen._action_tip(action), screen.TipFormat.S, true)
		assert_eq(screen._tip_panel.size, screen.tip_size_s,
				"五个基础动作严格复用同一个 S 框尺寸")
		assert_eq(screen._tip_label.get_theme_constant("line_spacing"),
				screen.tip_line_spacing)


func test_three_battle_utility_buttons_use_named_s_tooltips() -> void:
	var screen = await _make_screen()
	var cases: Array = [
		[screen.btn_switch, screen._switch_button_tip(), "切换出战英雄"],
		[screen.btn_backpack, screen._backpack_button_tip(), "打开背包"],
		[screen.btn_confirm, screen._end_turn_button_tip(), "结束回合"],
	]
	for entry: Array in cases:
		var button := entry[0] as Control
		assert_eq(entry[1], entry[2])
		button.mouse_entered.emit()
		assert_eq(screen._tip_panel.size, screen.tip_size_s,
				"切换、背包、结束均复用底部按钮 S 框")
		assert_eq(screen._tip_label.text, screen._keep_tip_terms_together(entry[2]))
		assert_eq(screen._tip_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
		button.mouse_exited.emit()
		assert_false(screen._tip_panel.visible)


func test_every_catalog_item_keeps_title_and_wrapped_body_on_the_same_center_axis() -> void:
	var screen = await _make_screen()
	var content_width: float = screen.tip_size_m.x - screen.tip_padding_horizontal_m * 2.0
	var checked := 0
	var expected := 0
	for tier: int in range(1, 4):
		var tier_items: Array[ItemData] = ItemCatalog.all_for_tier(tier)
		expected += tier_items.size()
		for item: ItemData in tier_items:
			screen._show_tip_at(Rect2(700.0, 800.0, 80.0, 80.0),
					"%s\n%s" % [tr(item.item_name), tr(item.description)],
					screen.TipFormat.M, false, screen.TipContentKind.ITEM, null, item)
			assert_eq(screen._tip_panel.size, screen.tip_size_m,
					"所有具名道具严格使用加高但未加宽的 M 框")
			assert_eq(screen._tip_rich.get_theme_constant("line_separation"),
					screen.tip_line_spacing)
			var body_width: float = content_width + screen._tip_rich.offset_right \
					- screen._tip_rich.offset_left
			var body_center: float = screen._tip_rich.offset_left + body_width * 0.5
			assert_almost_eq(body_center, content_width * 0.5, 0.51,
					"每件道具的左对齐正文列都按真实换行宽度整体居中")
			assert_gte(screen._tip_rich.offset_left, screen.ITEM_TIP_COLUMN_INSET)
			assert_lte(content_width + screen._tip_rich.offset_right,
					content_width - screen.ITEM_TIP_COLUMN_INSET,
					"正文左右均保留基础安全距离")
			assert_almost_eq(screen._tip_item_header.position.x,
					screen.ITEM_TIP_COLUMN_INSET, 0.01,
					"每件道具共用固定标题轨道，不再随名字数左右漂移")
			assert_true(screen._tip_item_rule.visible,
					"标题与正文以克制细分隔建立层级，不再只靠标题加粗")
			checked += 1
	assert_eq(checked, expected)
	assert_gt(checked, 0)


func test_resolution_bubble_motion_lands_at_pixel_crisp_rest_state() -> void:
	var screen = await _make_screen()
	screen.action_bubble_enter_duration = 0.08
	var expected: Vector2 = screen._action_bubble_target_position(0, screen.action_bubble_size)
	var bubble := Control.new()
	bubble.position = expected
	screen.add_child(bubble)
	var enter: Tween = screen._animate_bubble_enter(bubble, 0)
	assert_ne(bubble.position, expected, "揭示气泡从角色侧轻推入场，而不是首帧硬切")
	assert_lt(bubble.scale.x, 1.0, "入场首帧保留克制缩放，但不再使用强回弹")
	enter.custom_step(0.11)
	assert_eq(bubble.position, expected, "入场结束后落在角色自适应锚点")
	assert_almost_eq(bubble.scale.x, 1.0, 0.001,
			"入场结束严格恢复 1:1，避免像素图标持续缩放发糊")
	assert_almost_eq(bubble.modulate.a, 1.0, 0.001)


func test_switch_handoff_has_distinct_exit_and_entry_phases() -> void:
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	screen.switch_exit_duration = 0.10
	screen.switch_enter_duration = 0.12
	cd.offset_transform_position = Vector2.ZERO
	cd.modulate = Color.WHITE
	var base_material: Material = cd.material
	assert_true(cd.offset_transform_enabled,
			"角色显示节点已启用实际视觉位移，而不是只改一个无效属性")
	assert_true(cd.offset_transform_visual_only,
			"换人位移不改变原有容器布局与鼠标命中区域")
	var exit_tween: Tween = screen._animate_switch_out(cd, 0)
	exit_tween.custom_step(0.12)
	assert_eq(cd.offset_transform_position,
			Vector2(-screen.switch_travel_distance, screen.switch_vertical_drop),
			"旧英雄以规则像素步进收向己方边缘")
	var switch_material := cd.material as ShaderMaterial
	assert_not_null(switch_material, "旧英雄退场使用换人专用像素材质")
	assert_eq(switch_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_character_switch_blocks.gdshader")
	assert_almost_eq(float(switch_material.get_shader_parameter("switch_progress")), 1.0, 0.001,
			"规则像素带完全收束后才更换资源")
	assert_almost_eq(cd.modulate.a, 1.0, 0.001, "换人不再使用普通透明度偷懒淡出")
	var enter_tween: Tween = screen._animate_switch_in(cd, 0)
	assert_eq(cd.offset_transform_position,
			Vector2(-screen.switch_travel_distance, screen.switch_vertical_drop),
			"新英雄从同一己方边缘起步")
	assert_almost_eq(cd.modulate.a, 1.0, 0.001)
	enter_tween.custom_step(0.14)
	assert_eq(cd.offset_transform_position, Vector2.ZERO, "新英雄稳定重组回原战斗锚点")
	assert_almost_eq(cd.modulate.a, 1.0, 0.001, "新英雄入场完成后恢复完整可见度")
	assert_eq(cd.material, base_material, "入场完成卸载临时像素材质，恢复原角色渲染链")


func test_switch_pixel_shader_is_structured_and_distinct_from_death_erosion() -> void:
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	var base_material: Material = cd.material
	cd.set_switch_blocks(0.5, false, 8)
	var switch_material := cd.material as ShaderMaterial
	assert_not_null(switch_material)
	assert_eq(switch_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_character_switch_blocks.gdshader")
	var source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_character_switch_blocks.gdshader")
	assert_true(source.contains("band_rows"), "换人使用规则横向像素带")
	assert_true(source.contains("handoff_color"), "换人使用独立青绿交接边")
	assert_false(source.contains("hash21"), "换人不复用死亡侵蚀的随机噪声")
	assert_false(source.contains("silhouette_depth"), "换人不复用死亡效果的轮廓向内侵蚀")
	cd.reset_switch_blocks()
	assert_eq(cd.material, base_material, "临时换人材质复位后不污染存活态渲染链")


func test_switch_handoff_replaces_character_only_during_hidden_gap() -> void:
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	cd.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.switch_exit_duration = 0.02
	screen.switch_handoff_pause = 0.01
	screen.switch_enter_duration = 0.03
	var reserves: Array[int] = screen._get_reserve_slots(0)
	assert_false(reserves.is_empty(), "默认队伍存在可用替补")
	var target_slot: int = reserves[0]
	var old_path: String = cd.sprite_frames_path
	screen.battle.active_index[0] = target_slot
	var switching_players: Array[int] = [0]
	await screen._play_switch_handoff(switching_players)
	assert_ne(cd.sprite_frames_path, old_path, "退场隐藏后才把中央立绘替换为新英雄")
	assert_eq(cd.sprite_frames_path, screen.battle.active_hero(0).sprite_frames_path,
			"交接完成后中央立绘与核心出战槽一致")
	assert_eq(cd.offset_transform_position, Vector2.ZERO)
	assert_almost_eq(cd.modulate.a, 1.0, 0.001)


func test_death_switch_reuses_active_switch_pixel_entry() -> void:
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	cd.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.switch_enter_duration = 0.02
	var base_material: Material = cd.material
	var target_slot: int = screen._get_reserve_slots(0)[0]
	var old_path: String = cd.sprite_frames_path
	screen.battle.active_index[0] = target_slot
	await screen._death_switch_transition(0)
	assert_ne(cd.sprite_frames_path, old_path,
			"死亡补位在不可见交接期换成新英雄")
	assert_eq(cd.sprite_frames_path, screen.battle.active_hero(0).sprite_frames_path)
	assert_eq(cd.offset_transform_position, Vector2.ZERO)
	assert_almost_eq(cd.modulate.a, 1.0, 0.001,
			"死亡补位不再使用旧版透明淡入")
	assert_eq(cd.material, base_material,
			"像素带重组结束后与主动换人一样卸载临时材质")


func test_switch_handoff_force_refreshes_a_new_hero_already_lethal_in_snapshot() -> void:
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	cd.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.switch_exit_duration = 0.01
	screen.switch_handoff_pause = 0.0
	screen.switch_enter_duration = 0.01
	var target_slot: int = screen._get_reserve_slots(0)[0]
	var incoming: HeroData = screen.battle.heroes[0][target_slot]
	var old_path: String = cd.sprite_frames_path
	screen.battle.active_index[0] = target_slot
	screen.battle.hp[0][target_slot] = 0
	var switching_players: Array[int] = [0]
	await screen._play_switch_handoff(switching_players)
	assert_ne(cd.sprite_frames_path, old_path)
	assert_eq(cd.sprite_frames_path, incoming.sprite_frames_path,
			"同拍阵亡的新英雄仍先正确换入，死亡演出不会落到旧英雄身上")


func test_passive_free_switch_reuses_the_normal_switch_handoff() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h07.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.state = screen.State.PLAYER_SELECT
	screen.switch_exit_duration = 0.20
	screen.switch_handoff_pause = 0.01
	screen.switch_enter_duration = 0.08
	var cd: CharacterDisplay = screen.p1_char_display
	var old_path: String = cd.sprite_frames_path
	var target_slot: int = screen.p1_frame_slots[1]
	assert_true(screen.battle.is_free_switch_target(screen.PLAYER, target_slot),
			"星日提供的选择期换人被识别为被动免费切换")
	screen.timer_seconds = 1
	screen.game_timer.start(0.01)

	screen._free_switch_now(1)
	assert_true(screen._switch_handoff_running,
			"免费切换立即进入与普通换人共用的交接锁")
	assert_eq(screen.state, screen.State.RESOLVING,
			"交接期间暂时锁住选择输入，避免连续点击改写画面")
	assert_true(screen.game_timer.is_stopped(),
			"免费切换交接冻结选择倒计时，临界归零不会在 RESOLVING 状态吞掉提交")
	await get_tree().create_timer(0.06).timeout
	assert_eq(screen.timer_seconds, 1, "交接动画不额外消耗玩家选择时间")

	await get_tree().create_timer(0.36).timeout
	assert_false(screen._switch_handoff_running)
	assert_eq(screen.state, screen.State.PLAYER_SELECT)
	assert_false(screen.game_timer.is_stopped(), "免费切换完成后恢复原本正在运行的倒计时")
	assert_ne(cd.sprite_frames_path, old_path,
			"旧英雄完成退场后才替换为免费切换的新英雄")
	assert_eq(cd.sprite_frames_path, screen.battle.active_hero(screen.PLAYER).sprite_frames_path)
	assert_eq(cd.offset_transform_position, Vector2.ZERO)
	assert_eq(cd.material, null, "免费切换完成后卸载临时像素材质")
	assert_null(screen.find_child("SwitchAfterimageP1", true, false),
			"旧踏尘残影节点不会残留在恢复后的扫描交接链")
