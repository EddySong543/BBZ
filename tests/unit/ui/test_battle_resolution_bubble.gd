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


func test_active_resolution_bubble_uses_the_hero_skill_icon() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h21.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	var icon_path: String = screen._active_skill_icon_path(screen.PLAYER, screen.ACTIVE, [])
	var bubble := screen._spawn_action_circle(screen.PLAYER, screen.ACTIVE, icon_path) as Control
	var icon := bubble.get_node_or_null("ActionIcon") as TextureRect
	assert_not_null(icon, "主动技能揭示不再回退为“技能”二字")
	assert_eq(icon.texture.resource_path, "res://assets/sprites/heroes/h21/h21_skill.png")
	assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var cost_badge := screen.btn_special.get_node("CostPips") as IconBadge
	assert_gt(cost_badge.z_index, screen._special_icon.z_index,
			"h21 能量角标必须绘制在主动技能 icon 上方")


func test_empowered_wave_bubble_uses_diagonal_icon_switch_transition() -> void:
	var screen = await _make_screen()
	assert_almost_eq(screen.action_bubble_transform_duration, 0.60, 0.001,
			"技能转场时长为 0.6 秒")
	var events: Array = [{id = "longyuji_empowered", player = screen.PLAYER}]
	var spec: Dictionary = screen._action_bubble_transform_spec(screen.PLAYER, events)
	assert_eq(spec["icon_path"], "res://assets/sprites/heroes/h05/h05_skill.png")
	assert_ne(spec["color"], Color.WHITE, "龙御极使用金色像素落印，不用白色糊层")
	assert_eq(spec["exit_direction"], Vector2.ONE,
			"龙御极沿左上到右下收束")
	var bubble := screen._spawn_action_circle(screen.PLAYER, ActionDef.Action.ATTACK) as Control
	var old_icon := bubble.get_node("ActionIcon") as CanvasItem
	screen.action_bubble_transform_duration = 0.10
	var tween: Tween = screen._animate_action_bubble_transform(
			bubble, load(spec["icon_path"]) as Texture2D, spec["color"],
			spec["exit_direction"])
	var old_material := old_icon.material as ShaderMaterial
	var transformed_icon := bubble.get_node("TransformedActionIcon") as CanvasItem
	var new_material := transformed_icon.material as ShaderMaterial
	assert_not_null(old_material)
	assert_not_null(new_material)
	assert_eq(old_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_action_icon_switch_blocks.gdshader")
	assert_eq(old_material.get_shader_parameter("exit_direction"), Vector2.ONE)
	assert_false(bool(old_material.get_shader_parameter("reveal_behind")))
	assert_true(bool(new_material.get_shader_parameter("reveal_behind")),
			"新图标使用潮线后方互补遮罩")
	assert_null(bubble.get_node_or_null("PixelCover"),
			"转场作用于图标本体，不再用色块覆盖按钮")
	var pixel_tide := bubble.get_node("PixelTide") as ActionBubbleDiagonalTide
	assert_eq(pixel_tide.ink_color, spec["color"], "龙御极恢复可见金色像素潮")
	assert_eq(pixel_tide.exit_direction, Vector2.ONE)
	assert_eq(pixel_tide.GRID, Vector2i(9, 9), "像素块加粗为更低密度的九格潮面")
	assert_eq(pixel_tide.position, Vector2(14.0, 14.0),
			"像素潮限制在图标安全区，不覆盖按钮外框")
	pixel_tide.progress = 0.40
	var first_frontier := pixel_tide._frontier()
	pixel_tide.progress = 0.70
	assert_gt(pixel_tide._frontier(), first_frontier,
			"像素潮越过换图中点后继续同向推进，不再触底反扫")
	pixel_tide.progress = 0.50
	assert_gt(pixel_tide.debug_visible_block_count(), 20,
			"斜向潮头加厚，并包含独立于图标透明度的实色像素方块")
	assert_true(old_icon.visible)
	assert_true(transformed_icon.visible,
			"新旧图从开场即并存，由 shader 互补裁切而非先后隐藏节点")
	tween.custom_step(0.05)
	assert_true(old_icon.visible)
	assert_true(transformed_icon.visible)
	assert_almost_eq(float(old_material.get_shader_parameter("switch_progress")), 0.5, 0.01)
	assert_almost_eq(float(new_material.get_shader_parameter("switch_progress")), 0.5, 0.01,
			"潮头中点两张图共享同一裁切线，不产生透明留白")
	tween.custom_step(0.06)
	await get_tree().process_frame
	assert_false(old_icon.visible)
	assert_null(transformed_icon.material, "重组结束后卸载临时转场材质")
	assert_null(bubble.get_node_or_null("PixelTide"), "转场结束后不残留像素潮节点")
	var shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_action_icon_switch_blocks.gdshader")
	assert_true(shader_source.contains("diagonal_axis"))
	assert_true(shader_source.contains("diagonal_bands"))


func test_empowered_bubbles_do_not_repeat_their_names_as_result_tags() -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	assert_false(source.contains("tags[p].append({text = tr(\"龙御极\")"),
			"龙御极只由 Bubble 图标表达，不再重复显示结算飘字")
	assert_false(source.contains("tags[p].append({text = tr(\"双波\")"),
			"双波只由 Bubble 图标表达，不再重复显示结算飘字")


func test_h13_bubble_switch_direction_is_reverse_diagonal() -> void:
	var screen = await _make_screen()
	var events: Array = [{id = "h13_split_big_wave", player = screen.PLAYER}]
	var spec: Dictionary = screen._action_bubble_transform_spec(screen.PLAYER, events)
	assert_eq(spec["exit_direction"], -Vector2.ONE,
			"H13 沿右下到左上收束，与龙御极方向相反")
	var material: ShaderMaterial = screen._make_action_icon_switch_material(
			spec["color"], spec["exit_direction"], 0.0)
	assert_eq(material.get_shader_parameter("exit_direction"), -Vector2.ONE)


func test_h17_transform_shader_is_black_bottom_up_and_restores_base_material() -> void:
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	var base_material: Material = cd.material
	cd.set_transform_blocks(0.5)
	var transform_material := cd.material as ShaderMaterial
	assert_not_null(transform_material)
	assert_eq(transform_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_character_transform_blocks.gdshader")
	var source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_character_transform_blocks.gdshader")
	assert_true(source.contains("UV.y >= boundary"), "旧形从下向上被黑色像素覆盖")
	assert_true(source.contains("transform_ink"), "转变使用独立近黑像素墨色")
	assert_true(source.contains("frontier_phase"),
			"转变前沿使用多相位像素交错，慢速时也不会整排卡顿")
	var transform_state := {swapped = false}
	var transform_players: Array[int] = [screen.PLAYER]
	screen._set_h17_transform_phase(0.49, transform_players, transform_state)
	assert_false(transform_state["swapped"])
	screen._set_h17_transform_phase(0.51, transform_players, transform_state)
	assert_true(transform_state["swapped"], "单一连续相位跨过中点时完成换装")
	cd.reset_transform_blocks()
	assert_eq(cd.material, base_material)


func test_h04_and_h21_enemy_target_prompts_use_skill_icons() -> void:
	for hero_id: String in ["h04", "h21"]:
		BattleSetup.p1_heroes = [
			load("res://assets/data/heroes/%s.tres" % hero_id) as HeroData,
			load("res://assets/data/heroes/h01.tres") as HeroData,
			load("res://assets/data/heroes/h02.tres") as HeroData,
		]
		var screen = await _make_screen()
		screen.state = screen.State.PLAYER_SELECT
		var action: int = screen.ACTIVE if hero_id == "h21" else ActionDef.Action.ATTACK
		screen._maybe_arm_enemy_targets(action)
		var prompted := 0
		for frame: HeroFrame in screen.p2_frames:
			if frame._switch_icon != null and frame._switch_icon.visible:
				prompted += 1
				assert_eq(frame._switch_icon.texture.resource_path,
						"res://assets/sprites/heroes/%s/%s_skill.png" % [hero_id, hero_id])
				assert_lte(frame._switch_icon.size.x, 36.0,
						"技能 icon 收进菱形头像框的安全内切区")
				assert_lte(frame._switch_icon.size.y, 36.0)
				assert_false(frame._switch_label.visible,
						"选敌头像框显示技能 icon 时不再叠加攻/揪文字")
		assert_gt(prompted, 0)
		screen.queue_free()
		await get_tree().process_frame


func test_h10_strengthening_keeps_the_base_attack_animation_and_bubble() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h10.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	var cd: CharacterDisplay = screen.p1_char_display
	assert_true(cd.has_action_anim("attack"), "h10 正式资源包含攻击动画")
	assert_eq(screen._action_for_battle_juice(
			screen.PLAYER, ActionDef.Action.ATTACK, {}),
			ActionDef.Action.ATTACK,
			"剑气强化仍是普通波，必须走基础攻击的完整动作流程")
	var spec: Dictionary = screen._action_bubble_transform_spec(screen.PLAYER, [
		{id = "h10_jianqi_attack", player = screen.PLAYER, amount = 2},
	])
	assert_eq(spec["icon_path"], "res://assets/sprites/heroes/h10/h10_skill.png",
			"揭示基础攻击后才翻成剑气强化图标")
	screen.action_phase_duration = 0.02
	screen._play_battle_anims(
			ActionDef.Action.ATTACK, ActionDef.Action.CHARGE,
			[0, 0], [false, false], {})
	assert_eq(cd._sprite.animation, &"attack",
			"剑气强化结算进入战斗动画阶段时播放 h10 attack")


func test_h03_no_longer_uses_a_private_serial_clash_timeline() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h03.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.action_phase_duration = 0.02
	await screen._play_battle_anims(
			ActionDef.Action.ATTACK, ActionDef.Action.ATTACK,
			[2, 2], [false, false], {})
	assert_eq(screen._resolution_phase_trace, [
		"primary_action", "primary_impact",
	], "同一序位的双方攻击必须走公共演出，不再为尾火串成先后手")


func test_h07_entry_damage_uses_shared_hit_arc_after_switch_handoff() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h07.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.switch_exit_duration = 0.01
	screen.switch_handoff_pause = 0.0
	screen.switch_enter_duration = 0.01
	screen.action_phase_duration = 0.01
	screen.battle.active_index[screen.PLAYER] = 1
	await screen._play_battle_anims(
		ActionDef.Action.SWITCH, ActionDef.Action.CHARGE,
		[0, 0], [false, false], {
			active_before = [0, 0],
			h07_entry_impacts = [{
				player = screen.AI, source_player = screen.PLAYER,
				slot = screen.battle.active_index[screen.AI], amount = 1,
			}],
		})

	var impact_index: int = screen._resolution_phase_trace.find("h07_entry_arc:1")
	var primary_index: int = screen._resolution_phase_trace.find("primary_impact")
	assert_gte(impact_index, 0, "星日登场应调用战斗现有的普通受击弧形")
	assert_lt(impact_index, primary_index, "登场伤害必须在换人交接后、公共行动前完成")
	var source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	assert_false(source.contains("H07EntryImpactFxScript"),
		"星日不得再创建程序化像素形状层")


func test_h19_transfer_finishes_inside_the_current_public_action_column() -> void:
	var screen = await _make_screen()
	screen.action_phase_duration = 0.01
	screen.h19_transfer_primary_hold_duration = 0.01
	screen.h19_transfer_duration = 0.02
	var target_slot: int = screen.p2_frame_slots[1]
	await screen._play_battle_anims(
			ActionDef.Action.BIG_ATTACK, ActionDef.Action.ATTACK,
			[2, 2], [false, false], {
				h19_transfers = [{
					player = screen.AI, from = screen.p2_frame_slots[0], to = target_slot,
					amount = 2, actual = 2, hp_damage = 2, shield_damage = 0,
				}],
			})
	var primary_impact: int = screen._resolution_phase_trace.find("primary_impact")
	var transfer_start: int = screen._resolution_phase_trace.find(
			"h19_transfer_start:%d:%d" % [screen.AI, target_slot])
	var reserve_impact: int = screen._resolution_phase_trace.find(
			"h19_reserve_impact:%d:%d" % [screen.AI, target_slot])
	assert_gt(transfer_start, primary_impact,
			"公共行动序位必须先让主目标伤害落地")
	assert_gt(reserve_impact, transfer_start)
	assert_eq(screen._resolution_phase_trace.count("primary_action"), 1,
			"同序位双方攻击与乌骓转移仍属于一个公共行动列")


func test_h11_damage_and_switch_precede_single_public_action() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h11.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	BattleSetup.p2_heroes = [
		load("res://assets/data/heroes/h03.tres") as HeroData,
		load("res://assets/data/heroes/h04.tres") as HeroData,
		load("res://assets/data/heroes/h05.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.action_phase_duration = 0.02
	screen.switch_exit_duration = 0.01
	screen.switch_handoff_pause = 0.0
	screen.switch_enter_duration = 0.01
	screen.h11_pre_switch_damage_hold = 0.01
	screen.h11_bite_close_duration = 0.01
	screen.h11_bite_impact_hold = 0.0
	screen.h11_bite_release_duration = 0.01
	screen.battle.active_index[screen.AI] = 1
	await screen._play_battle_anims(
			ActionDef.Action.ATTACK, ActionDef.Action.SWITCH,
			[0, 0], [false, false], {
				active_before = [0, 0],
				h11_switch_chases = [{
					player = screen.AI, slot = 0, amount = 4,
					source_player = screen.PLAYER,
				}],
			})
	var damage_index: int = screen._resolution_phase_trace.find("h11_damage:1")
	var bite_index: int = screen._resolution_phase_trace.find("h11_bite:1")
	var handoff_index: int = screen._resolution_phase_trace.find("h11_switch_and_action:1")
	assert_gte(bite_index, 0, "影狩真伤必须生成上下颌闭拢的逐帧像素撕咬")
	assert_lte(bite_index, damage_index, "撕咬先起势并在闭拢拍落下真伤")
	assert_gte(damage_index, 0, "先播放被换下英雄受到影狩伤害")
	assert_gt(handoff_index, damage_index,
			"伤害反馈完成后才进行正常换人交接")
	assert_eq(screen._resolution_phase_trace.count("primary_action_juice:0"), 1,
			"h11 选择攻击时只能由公共行动流程播放一次，不能与技能前置动作重叠")
	assert_gt(screen._resolution_phase_trace.find("primary_action_juice:0"), handoff_index,
			"真伤和换人前置段结束后才进入公共行动流程")


func test_h11_bite_is_centered_on_character_sprite_rect_at_compact_size() -> void:
	var screen = await _make_screen()
	assert_eq(screen.h11_bite_size, Vector2(208.0, 208.0),
			"撕咬不再沿用覆盖整个 CharacterDisplay 的 300 像素尺寸")
	assert_eq(screen.h11_bite_close_duration, 0.22)
	assert_eq(screen.h11_bite_impact_hold, 0.04,
			"闭合命中后只保留短促停顿，不拖成金属机关感")
	assert_eq(screen.h11_bite_release_duration, 0.08,
			"空白回收帧应尽快结束，避免无意义延长效果节点寿命")
	var sprite_rect: Rect2 = screen._character_sprite_rect(screen._cd(screen.AI))
	var effect: Control = screen._spawn_h11_bite_fx(screen.AI)
	assert_eq(effect.position,
			(sprite_rect.get_center() - screen.h11_bite_size * 0.5).round(),
			"撕咬必须锚定实际立绘矩形中心，而不是 768 像素显示容器中心")
	assert_eq(effect.size, Vector2(208.0, 208.0))
	effect.queue_free()


func test_h16_playback_partition_keeps_pursuit_out_of_the_primary_hit() -> void:
	var screen = await _make_screen()
	var events: Array = [
		{id = "damage_taken", player = screen.AI, slot = 0, amount = 2},
		{id = "switch", player = screen.PLAYER, from_to = [0, 1],
			resolution_phase = "h16_pursuit_switch"},
		{id = "h16_reserve_pursuit", player = screen.PLAYER, slot = 1,
			target = 0, hp_damage = 2, damage_total = 2, target_defeated = false},
		{id = "damage_taken", player = screen.AI, slot = 0, amount = 2,
			resolution_phase = "h16_pursuit", pursuit_player = screen.PLAYER},
	]
	var pursuits: Array[Dictionary] = screen._h16_pursuit_specs(events)
	assert_eq(pursuits.size(), 1)
	assert_eq(pursuits[0]["player"], screen.PLAYER)
	assert_eq(pursuits[0]["target"], 0)
	assert_eq(pursuits[0]["hp_damage"], 2)
	assert_true(screen._is_h16_pursuit_detail_event(events[3]),
			"追击伤害不能再次并入主攻击伤害")
	assert_false(screen._is_h16_pursuit_detail_event(events[0]))


func test_h16_runtime_playback_is_strictly_serial() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h16.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.action_phase_duration = 0.02
	screen.switch_exit_duration = 0.01
	screen.switch_handoff_pause = 0.0
	screen.switch_enter_duration = 0.01
	screen.battle.active_index[screen.PLAYER] = 1
	await screen._play_battle_anims(
		ActionDef.Action.ATTACK, ActionDef.Action.CHARGE,
		[0, 2], [false, false], {
			active_before = [0, 0],
			h16_pursuits = [{
				player = screen.PLAYER, from_slot = 0, slot = 1, target = 0,
				hp_damage = 2, shield_damage = 0, damage_total = 2,
				connected = true, target_defeated = false, target_tags = [],
			}],
		})
	assert_eq(screen._resolution_phase_trace, [
		"primary_action", "primary_impact", "h16_switch:0",
		"h16_attack:0", "h16_impact:0",
	], "队友出招、主伤害、广寒换入、广寒攻击与追击伤害必须严格串行")


func test_reserve_hit_feedback_only_targets_the_matching_avatar() -> void:
	var screen = await _make_screen()
	var target_slot: int = screen.p2_frame_slots[1]
	var other_slot: int = screen.p2_frame_slots[2]
	var target_index: int = screen.p2_frame_slots.find(target_slot)
	var other_index: int = screen.p2_frame_slots.find(other_slot)
	var target_frame: HeroFrame = screen.p2_frames[target_index]
	var other_frame: HeroFrame = screen.p2_frames[other_index]
	screen._impact_reserve_slot(screen.AI, target_slot, 2)
	var impact_fx := target_frame.get_node_or_null("ReserveAvatarImpactFx")
	assert_not_null(impact_fx,
			"替补受击必须额外生成贴合菱形头像轮廓的像素冲击框，不能只靠轻微缩放染色")
	impact_fx.progress = 0.32
	assert_gt(int(impact_fx.debug_visible_block_count()), 12,
			"冲击框在头像小尺寸下仍需有足够的像素结构可读")
	assert_gte(absf(float(target_frame.get_meta(&"reserve_impact_recoil_x"))), 6.0,
			"第一拍必须有清楚的定向后坐，不能仍是肉眼难辨的3像素轻晃")
	var compress_scale: Vector2 = target_frame.get_meta(&"reserve_impact_compress_scale")
	assert_lt(compress_scale.x, 1.0,
			"后坐同时横向压缩头像，形成明确受力而非普通按钮放大")
	assert_gt(compress_scale.y, 1.0)
	var active_numbers: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_eq(active_numbers.size(), 1,
			"替补伤害必须通过公共池生成一个独立数字")
	assert_eq(active_numbers[0]["anchor_key"],
			"reserve:%d:%d" % [screen.AI, target_slot])
	assert_eq(active_numbers[0]["font_size"], 36,
			"替补沿用公共样式，只使用更紧凑的字号档位")
	assert_null(target_frame.get_node_or_null("ReserveDamage"),
			"替补头像内不再临时创建另一套伤害Label")
	assert_null(other_frame.get_node_or_null("ReserveDamage"),
			"未命中的替补头像以及整排不得被连带反馈")
	assert_null(other_frame.get_node_or_null("ReserveAvatarImpactFx"),
			"菱形冲击框只能出现在实际承受溢出伤害的替补头像")


func test_h19_reserve_hit_uses_two_tone_flash_and_damped_shake() -> void:
	var screen = await _make_screen()
	var target_slot: int = screen.p2_frame_slots[1]
	var target_index: int = screen.p2_frame_slots.find(target_slot)
	var target_frame: HeroFrame = screen.p2_frames[target_index]
	var base_scale := target_frame.scale
	screen._impact_reserve_slot(
		screen.AI, target_slot, 2, ActionDef.Pen.NORMAL, false, false, &"transferred")
	assert_null(target_frame.get_node_or_null("ReserveAvatarImpactFx"),
			"H19替补落点不再生成容易误读为按钮脉冲的方块菱形圈")
	var hit_glow := target_frame.get_node_or_null("ReserveAvatarHitGlow")
	assert_not_null(hit_glow,
			"H19必须生成贴合头像菱形的透明红光层，不能只给父节点写一个难辨的暗色modulate")
	assert_eq(target_frame.scale, base_scale,
			"H19受击只使用变色和位移，不再挤压替补头像")
	var offsets: PackedFloat32Array = target_frame.get_meta(&"reserve_impact_shake_offsets")
	assert_eq(Array(offsets), [18.0, -13.0, 9.0, -5.0, 0.0],
			"敌方替补使用清楚的18→-13→9→-5→0衰减抖动，不得随机漂移")
	var y_offsets: PackedFloat32Array = target_frame.get_meta(
			&"reserve_impact_shake_y_offsets")
	assert_eq(Array(y_offsets), [-4.0, 3.0, -2.0, 1.0, 0.0],
			"局部抖动加入克制的纵向错拍，避免退化成不易察觉的水平平移")
	var flash_colors: Array = target_frame.get_meta(&"reserve_impact_flash_colors")
	assert_eq(flash_colors, [Color(1.68, 0.62, 0.58), Color(1.15, 0.30, 0.32)],
			"H19使用真实可见的亮红闪与红色余光，不再用近黑暗红把头像压没")
	assert_eq(screen._fx.debug_active_damage_numbers().size(), 0,
			"溢出数字不能在替补开始受力前提前出现")
	assert_almost_eq(float(target_frame.get_meta(&"reserve_impact_number_delay")),
			0.05, 0.001, "替补数字锁在第一次最大位移时出现")
	var base_position := target_frame.position
	var max_runtime_distance: float = 0.0
	var max_runtime_glow: float = 0.0
	for _sample: int in 6:
		await get_tree().create_timer(0.012, true, false, true).timeout
		max_runtime_distance = maxf(
			max_runtime_distance, target_frame.position.distance_to(base_position))
		max_runtime_glow = maxf(
			max_runtime_glow, float(hit_glow.call("debug_strength")))
	assert_true(target_frame.has_meta(&"reserve_impact_driver"),
			"取样窗口内H19受击时间轴必须仍在运行，不能首帧直接完成归位")
	assert_gt(max_runtime_distance, 4.0,
			"运行时必须在任一受力拍明显移动HeroFrame，不能依赖单帧取样碰运气")
	assert_gt(max_runtime_glow, 0.45,
			"受击取样窗口内的菱形红光必须达到清楚可读的强度")


func test_h19_transfer_events_are_partitioned_out_of_primary_reserve_hits() -> void:
	var screen = await _make_screen()
	var events: Array = [
		{id = "damage_taken", player = screen.AI, slot = 0, amount = 2},
		{id = "damage_taken", player = screen.AI, slot = 2, amount = 3,
			src = "h19_transfer"},
		{id = "h19_damage_transferred", player = screen.AI, from = 0, to = 2,
			amount = 3, actual = 3, hp_damage = 3, shield_damage = 0},
	]
	var specs: Array[Dictionary] = screen._h19_transfer_specs(events)
	assert_eq(specs.size(), 1)
	assert_eq(specs[0]["player"], screen.AI)
	assert_eq(specs[0]["to"], 2)
	assert_eq(specs[0]["hp_damage"], 3)
	assert_true(screen._is_h19_transfer_detail_event(events[1]),
			"转移伤害必须脱离主命中拍，抵达头像后才单独反馈")
	assert_false(screen._is_h19_transfer_detail_event(events[0]))


func test_h19_transfer_trail_uses_distinct_gather_travel_and_impact_forms() -> void:
	var trail = load("res://src/ui/components/damage_transfer_trail.gd").new()
	add_child_autofree(trail)
	trail.configure(Vector2(320.0, 680.0), Vector2(1480.0, 170.0))
	trail.gather_progress = 0.2
	var early_radii: Array[float] = trail.debug_gather_radii()
	trail.gather_progress = 0.8
	var late_radii: Array[float] = trail.debug_gather_radii()
	assert_eq(early_radii.size(), 3)
	for index: int in early_radii.size():
		assert_lt(late_radii[index], early_radii[index],
				"每段蓄力弧都必须向起点收缩，不能沿路线逐节向外生长")
	trail.gather_progress = 0.6
	assert_true(trail.debug_source_gather_visible(),
			"溢出残波在出战人物附近先显形一拍，不能生成后立刻飞走")
	assert_eq(trail.debug_visual_kind(), &"condensed_arc_wave")
	assert_eq(trail.debug_gather_arc_count(), 3,
			"蓄力必须是三段向内收束的断弧，不能沿飞行路线逐节长出虫身")
	assert_eq(trail.debug_palette(), [
		Color("08060a"), Color("1a0d13"), Color("4b202a"),
	], "整体维持绛黑配色，不因重做形态退回灰色")
	assert_false(trail.debug_uses_square_blocks(),
			"溢出伤害不再以一串方格作为视觉主体")
	assert_false(trail.debug_has_full_length_core(),
			"飞行残波不能再有贯穿中间的高光内芯")
	assert_eq(trail.debug_tail_sliver_count(), 0,
			"取消交替分布在两侧、容易被看成虫足的短残片")
	trail.gather_progress = 1.0
	var gather_end: float = trail.debug_visible_head_t()
	trail.progress = 0.0001
	assert_almost_eq(trail.debug_visible_head_t(), gather_end, 0.001,
			"收束末帧与正式飞行首帧必须连续，不能闪空或重复刷新")
	trail.progress = 0.5
	assert_gte(trail.debug_visible_segment_count(), 8,
			"转移不能退化成孤立光点，必须保留连续收尖的弧形残波")
	assert_gt(trail.debug_width_at_ratio(0.68), trail.debug_width_at_ratio(0.0),
			"残波从尖尾扩展到中前段")
	assert_gt(trail.debug_width_at_ratio(0.68), trail.debug_width_at_ratio(1.0),
			"波头必须重新收尖，不能形成虫子式粗圆头")
	assert_lt(trail.point_at(0.5).y, 350.0,
			"雷片重组只发生在局部，整体仍沿原先明显拱起的大弧线移动")
	assert_eq(trail.point_at(0.0), Vector2(320.0, 680.0))
	assert_eq(trail.point_at(1.0), Vector2(1480.0, 170.0),
			"轨迹必须精确落到指定替补头像中心")
	trail.impact_progress = 0.5
	assert_eq(trail.debug_impact_fragment_count(), 2,
			"命中后主弧裂成上下两片短弧，不缩回也不残留粉末")
	var impact_fragments: Array[PackedVector2Array] = trail.debug_impact_fragment_points()
	assert_eq(impact_fragments.size(), 2)
	assert_gt(impact_fragments[0][1].distance_to(impact_fragments[1][1]), 12.0,
			"两片命中弧必须在目标两侧明显分开，而不是叠回一条粗线")
	assert_true(trail.debug_travel_hidden_during_impact(),
			"命中阶段只保留裂散反馈，不能继续显示一整条虫形残波")


func test_h19_playback_reads_main_cap_then_moves_to_one_reserve() -> void:
	var screen = await _make_screen()
	assert_almost_eq(screen.h19_transfer_source_hold_duration, 0.20, 0.001,
			"残波必须在主目标附近可见蓄留一拍，而不是用不可见延迟代替")
	assert_almost_eq(screen.h19_transfer_duration, 0.46, 0.001,
			"溢出段保持可追踪的弧线飞行，不能沿用过快的0.30秒")
	assert_almost_eq(screen.h19_transfer_impact_duration, 0.14, 0.001,
			"命中裂散与替补红光共同保留一拍，随后干净清理")
	screen.action_phase_duration = 0.02
	screen.h19_transfer_primary_hold_duration = 0.01
	screen.h19_transfer_source_hold_duration = 0.01
	screen.h19_transfer_duration = 0.04
	var target_slot: int = screen.p2_frame_slots[2]
	await screen._play_battle_anims(
			ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE,
			[0, 2], [false, false], {
				h19_transfers = [{
					player = screen.AI, from = screen.p2_frame_slots[0], to = target_slot,
					amount = 3, actual = 3, hp_damage = 3, shield_damage = 0,
				}],
			})
	var primary_index: int = screen._resolution_phase_trace.find("primary_impact")
	var transfer_index: int = screen._resolution_phase_trace.find(
			"h19_transfer_start:%d:%d" % [screen.AI, target_slot])
	var reserve_index: int = screen._resolution_phase_trace.find(
			"h19_reserve_impact:%d:%d" % [screen.AI, target_slot])
	assert_gt(transfer_index, primary_index,
			"主目标先明确显示封顶后的1点伤害，再开始转移")
	assert_gt(reserve_index, transfer_index,
			"转移抵达后才允许替补头像受击和弹出独立数字")
	var anchors: Array[String] = []
	for number: Dictionary in screen._fx.debug_active_damage_numbers():
		anchors.append(String(number["anchor_key"]))
	assert_true(anchors.has("character:%d" % screen.AI), "主目标保留自己的封顶伤害数字")
	assert_true(anchors.has("reserve:%d:%d" % [screen.AI, target_slot]),
			"溢出伤害在指定替补头像处显示为第二个独立数字")
	assert_eq(anchors.count("reserve:%d:%d" % [screen.AI, target_slot]), 1,
			"H19 替补不能在主命中拍提前播放后又重复一次")


func test_public_damage_numbers_use_one_restrained_palette_and_weight_language() -> void:
	var screen = await _make_screen()
	var profile: Dictionary = screen._fx.debug_damage_number_profile()
	assert_eq(profile["font_path"], "res://assets/font/zlabs_pixel_ui.tres")
	assert_almost_eq(float(profile["font_embolden"]), 0.28, 0.001)
	assert_eq(profile["font_color"], Color("d8c8b2"))
	assert_eq(profile["outline_color"], Color("211b1a"))
	assert_eq(profile["shadow_color"], Color(0.05, 0.04, 0.04, 0.52))
	assert_eq(profile["shadow_offset"], Vector2i(2, 2))
	assert_eq(profile["normal_font_size"], 44)
	assert_eq(profile["heavy_font_size"], 51,
			"大伤只比普通伤害大约15%，不再换成抢眼颜色")
	assert_eq(profile["reserve_font_size"], 36)
	assert_eq(profile["damage_type_colors"].values().duplicate().all(
			func(color: Color) -> bool: return color == Color("d8c8b2")), true,
			"普通、重击、穿透与真伤统一为同一克制色")
	assert_false(profile["random_spawn_offset"],
			"低频回合制伤害数字不使用看似错位的随机出生点")


func test_damage_number_overlap_uses_deterministic_center_right_left_lanes() -> void:
	var screen = await _make_screen()
	for amount: float in [1.0, 0.5, 1.5]:
		screen._fx._pop_damage(screen.AI, amount)
	var active_numbers: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_eq(active_numbers.size(), 3)
	assert_eq(active_numbers.map(func(entry: Dictionary) -> int:
			return int(entry["lane"])), [0, 1, 2])
	assert_eq(active_numbers.map(func(entry: Dictionary) -> Vector2:
			return entry["lane_offset"]), [
		Vector2.ZERO, Vector2(24.0, -14.0), Vector2(-24.0, -14.0),
	], "同目标叠加使用固定轨道，不依赖随机数")


func test_damage_number_special_state_and_lanes_survive_pool_reuse() -> void:
	var screen = await _make_screen()
	screen._fx._pop_damage(screen.AI, 1.0, ActionDef.Pen.NORMAL, &"limited")
	var profile: Dictionary = screen._fx.debug_damage_number_profile()
	var first: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_almost_eq(float(profile["limited_tide_duration"]), 0.22, 0.001,
			"游丝引黑潮先于伤害数字完成上涌，不能拖成长转场")
	assert_almost_eq(float(profile["limited_reveal_delay"]), 0.10, 0.001,
			"数字延后到潮头覆盖后显露，避免与黑潮同时硬弹出")
	assert_eq(profile["limited_tide_color"], Color("17131d"),
			"复用H13已通过的近黑像素潮语言")
	assert_eq(first[0]["special_state"], &"limited",
			"h18等后续机制只向公共系统提交语义状态，不另造临时数字")
	assert_true(bool(first[0]["limit_tide_visible"]),
			"limited状态必须先显示覆盖数字区域的黑色像素潮")
	assert_false(bool(first[0]["number_revealed"]),
			"像素潮开始时最终伤害数字尚未显露")
	assert_eq(first[0]["limit_tide_direction"], &"bottom_up")
	screen._fx.debug_step_active_damage_limit_tides(0.13)
	var revealed: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_true(bool(revealed[0]["number_revealed"]),
			"潮头越过数字后才显露最终实际伤害")
	assert_true(bool(revealed[0]["limit_tide_visible"]),
			"数字显露时黑潮仍在向上离场，形成自然揭示而非瞬切")
	assert_gt(float(revealed[0]["limit_tide_progress"]), 0.45)
	assert_gt(int(revealed[0]["limit_tide_visible_blocks"]), 20,
			"潮面必须保留H13式粗像素块密度，不能再次退化成几条看不见的细线")
	screen._fx.debug_step_active_damage_limit_tides(0.13)
	var settled: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_false(bool(settled[0]["limit_tide_visible"]),
			"黑潮单向越过后立即清理，只留下可读伤害数字")
	await get_tree().create_timer(0.72).timeout
	assert_eq(screen._fx.debug_active_damage_numbers().size(), 0,
			"数字回收时必须同步释放确定性轨道")
	screen._fx._pop_damage(screen.AI, 0.5)
	var reused: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_eq(reused[0]["lane"], 0,
			"同一目标下一次结算重新从中央轨道开始")
	assert_false(bool(reused[0]["limit_tide_visible"]),
			"池化Label复用为普通伤害时必须彻底隐藏游丝引黑潮")
	assert_true(bool(reused[0]["number_revealed"]),
			"普通伤害数字仍保持立即出现，不继承H18延迟")


func test_battle_playback_routes_limited_state_into_the_public_damage_number() -> void:
	var screen = await _make_screen()
	# 避开 0.045s 命中顿帧把一个极短的结算尾拍按 time_scale 拉长到潮水结束之后；
	# 本测试只验证公共编排确实把 limited 语义传进数字系统。
	screen.action_phase_duration = 0.001
	await screen._play_battle_anims(
		ActionDef.Action.BIG_ATTACK, ActionDef.Action.CHARGE,
		[0, 3], [false, false], {
			pen = [ActionDef.Pen.NORMAL, ActionDef.Pen.NORMAL],
			damage_number_states = [&"normal", &"limited"],
		})
	var active_numbers: Array[Dictionary] = screen._fx.debug_active_damage_numbers()
	assert_eq(active_numbers.size(), 1)
	assert_eq(active_numbers[0]["anchor_key"], "character:%d" % screen.AI)
	assert_eq(active_numbers[0]["special_state"], &"limited",
			"战斗编排必须把核心事件聚合出的limited状态交给公共数字出口")
	# 这一断言只锁公共编排入口；上一测试已用 custom_step 精确锁定黑潮时序。
	# 整文件串行跑时，前序命中的全局 hitstop 可能让这枚 0.22s 黑潮在 await 返回前完成。
	assert_true(bool(active_numbers[0]["limit_tide_visible"]) \
			or bool(active_numbers[0]["number_revealed"]),
			"实战必须处于黑潮揭示中，或已经完成揭示并留下最终数字")
	if bool(active_numbers[0]["limit_tide_visible"]):
		assert_true(float(active_numbers[0]["limit_tide_progress"]) > 0.0,
				"黑潮仍在场时必须已经开始从下向上推进")


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
	assert_eq(screen.TipFormat.size(), 4,
			"主动技能拥有独立紧凑尺寸，不得挤占 S/M/L 的既有职责")
	assert_true(screen.TipFormat.has("M"), "道具说明正式使用 M 框，不再伪装成 L 框")
	assert_true(screen.TipFormat.has("ACTIVE"), "主动技能使用独立紧凑框")
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


func test_active_skill_tooltip_has_its_own_compact_size() -> void:
	var screen = await _make_screen()
	screen._show_tip_at(Rect2(700.0, 800.0, 80.0, 80.0),
			"主动技能的紧凑说明", screen.TipFormat.ACTIVE, false,
			screen.TipContentKind.SKILL)
	assert_eq(screen._tip_panel.size, screen.tip_size_active)
	assert_lt(screen.tip_size_active.x, screen.tip_size_l.x,
			"主动技能框必须比头像技能与 Buff 共用的 L 框更紧凑")
	assert_lt(screen.tip_size_active.y, screen.tip_size_l.y)
	screen._show_tip_at(Rect2(700.0, 800.0, 80.0, 80.0),
			"头像技能说明", screen.TipFormat.L, false,
			screen.TipContentKind.AVATAR_SKILL)
	assert_eq(screen._tip_panel.size, screen.tip_size_l,
			"新增主动技能尺寸不能改动头像技能与 Buff 的 L 框")


func test_h10_without_team_sword_qi_uses_the_common_disabled_state() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h10.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.state = screen.State.PLAYER_SELECT
	screen.battle.energy[screen.PLAYER] = ActionDef.MAX_ENERGY
	screen._refresh_action_affordance()
	assert_false(screen.btn_special.visible,
			"昴日不再占用独立主动技能按钮")
	screen._on_circle_pressed(ActionDef.Action.ATTACK, screen.btn_attack)
	assert_true(screen.jianqi_attack_picker.visible,
			"选择波后才显示剑气强化分支")
	assert_true(screen.btn_jianqi_attack.disabled,
			"少于2点剑气时强化分支保持统一禁用态")
	screen.battle.set_team_status(screen.PLAYER, "jianqi", 2)
	screen._refresh_action_affordance()
	assert_false(screen.btn_jianqi_attack.disabled,
			"2点剑气时普通波可选择穿防强化")


func test_h17_h21_h22_keep_preview_selection_until_queue_cancel() -> void:
	for hero_id: String in ["h17", "h21", "h22"]:
		BattleSetup.p1_heroes = [
			load("res://assets/data/heroes/%s.tres" % hero_id) as HeroData,
			load("res://assets/data/heroes/h01.tres") as HeroData,
			load("res://assets/data/heroes/h02.tres") as HeroData,
		]
		var screen = await _make_screen()
		screen.state = screen.State.PLAYER_SELECT
		screen.battle.energy[screen.PLAYER] = ActionDef.MAX_ENERGY
		screen._refresh_action_affordance()
		assert_false(screen.btn_special.disabled, "%s 主动技能测试前置必须合法" % hero_id)
		screen._dispatch_command_drop({
			kind = "action", action = screen.ACTIVE, button = screen.btn_special,
		})
		screen._refresh_action_modifiers()
		var juice := screen.btn_special.get_node("ButtonJuice") as ButtonJuice
		assert_true(bool(juice.get("_selected")),
				"%s 的来源技能按钮应保留预选反馈" % hero_id)
		assert_ne(screen.btn_special.modulate, Color.WHITE)
		assert_eq(screen._turn_command_queue.size(), 1)
		assert_not_null(screen._command_order_row.get_node_or_null("Step0"),
				"%s 的真正使用状态仍由顺序槽技能美术表达" % hero_id)
		var cancel := screen._command_order_row.find_child("Cancel", true, false) as Button
		cancel.pressed.emit()
		await get_tree().process_frame
		assert_false(bool(juice.get("_selected")),
				"%s 从顺序槽取消后恢复普通状态" % hero_id)
		assert_true(screen._turn_command_queue.is_empty())
		screen.queue_free()
		await get_tree().process_frame


func test_h10_modifier_is_stored_on_the_base_action_queue_entry() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h10.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.state = screen.State.PLAYER_SELECT
	screen.battle.energy[screen.PLAYER] = ActionDef.MAX_ENERGY
	screen.battle.set_team_status(screen.PLAYER, "jianqi", 2)
	screen._refresh_action_affordance()
	assert_true(screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.ATTACK, button = screen.btn_attack,
	}))
	assert_true(screen._dispatch_command_drop({
		kind = "modifier", button = screen.btn_jianqi_attack,
	}))
	var sequence: Array[Dictionary] = screen._command_sequence_for_submit()
	assert_eq(int(sequence[0]["action"]), ActionDef.Action.ATTACK)
	assert_true(bool(sequence[0]["jianqi_attack"]),
			"剑气强化作为基础攻击字段提交，不生成第二个主动行动")
	assert_eq(screen._turn_command_queue.size(), 1)
	var cancel := screen._command_order_row.find_child("Cancel", true, false) as Button
	cancel.pressed.emit()
	await get_tree().process_frame
	assert_false(screen._jianqi_attack_armed)
	assert_true(screen._turn_command_queue.is_empty())


func test_h24_primary_button_only_arms_the_selected_action_variant() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h24.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.state = screen.State.PLAYER_SELECT
	screen.battle.energy[screen.PLAYER] = ActionDef.MAX_ENERGY
	screen._refresh_action_affordance()
	assert_true(screen.btn_special.visible, "并封出战时必须拥有统一底部技能入口")
	assert_false(screen.btn_special.disabled)
	var cap_badge := screen.btn_special.get_node("CostPips") as IconBadge
	assert_true(cap_badge.visible)
	assert_eq(cap_badge.number, 1,
			"并封左上角标改为黑色能量点加数字1")
	assert_eq(cap_badge.icon_modulate, IconPipRow.DISABLED_CAPACITY_COLOR,
			"并封角标与动态上限共用同一种黑色能量点语义")
	assert_eq(screen.btn_h24_discount.get_node("CapCost").number, 1,
			"替补并封的行动分支入口同步更新角标数字")
	screen._on_circle_pressed(screen.ACTIVE, screen.btn_special)
	assert_eq(screen.selected_action, -1,
			"并封技能键只预选减费模式，不能被误改为独立 ACTIVE 行动")
	assert_true(screen._energy_cap_discount_armed)
	screen._on_circle_pressed(ActionDef.Action.ATTACK, screen.btn_attack)
	assert_eq(screen.selected_action, ActionDef.Action.ATTACK)
	assert_true(screen._energy_cap_discount_armed,
			"选定正费用行动后保留并封减费变体")
	assert_false(screen.h24_discount_picker.visible,
			"并封出战时不再重复显示第二个临时技能入口")
	screen._on_circle_pressed(screen.ACTIVE, screen.btn_special)
	assert_eq(screen.selected_action, ActionDef.Action.ATTACK,
			"取消并封变体不得取消或替换当前行动")
	assert_false(screen._energy_cap_discount_armed)


func test_leaving_h24_restores_normal_active_skill_cost_color() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h24.tres") as HeroData,
		load("res://assets/data/heroes/h21.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	var badge := screen.btn_special.get_node("CostPips") as IconBadge
	screen._refresh_action_cost_badges()
	assert_eq(badge.icon_modulate, IconPipRow.DISABLED_CAPACITY_COLOR,
			"h24 自身继续使用黑色上限点")
	screen.battle.active_index[screen.PLAYER] = 1
	screen._refresh_action_cost_badges()
	assert_eq(badge.icon_modulate, Color.WHITE,
			"切换到普通主动技后恢复正常能量点，不继承 h24 的黑色")


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


func test_switching_into_h07_uses_the_once_per_turn_free_switch_path() -> void:
	BattleSetup.p1_heroes = [
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h07.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	]
	var screen = await _make_screen()
	screen.state = screen.State.PLAYER_SELECT
	var h07_slot: int = screen.p1_frame_slots[1]
	assert_true(screen.battle.is_free_switch_target(screen.PLAYER, h07_slot),
		"目标是星日时也应识别为本回合一次免费切换")

	screen._on_switch_candidate_pressed(1)
	assert_eq(screen.battle.active_index[screen.PLAYER], h07_slot,
		"点击替补星日应直接完成免费切换预览")
	assert_eq(screen.selected_action, -1,
		"免费切换不占用本回合动作槽")
	assert_true(screen._switch_handoff_running,
		"免费切入星日应复用正常换人交接")


func test_switch_handoff_updates_main_hp_bar_with_the_incoming_character() -> void:
	var screen = await _make_screen()
	var old_slot: int = screen.battle.active_index[screen.PLAYER]
	screen.battle.hp[screen.PLAYER][old_slot] = 2
	screen._update_hp_labels()
	assert_almost_eq(float(screen.p1_heart_row._cur), 1.0, 0.001)

	var incoming_slot: int = screen.p1_frame_slots[1]
	var key: String = screen._resolution_frame_override_key(
		screen.PLAYER, incoming_slot)
	screen._resolution_frame_value_overrides[key] = {hp = 9, shield = 2}
	screen.battle.active_index[screen.PLAYER] = incoming_slot
	screen.switch_exit_duration = 0.01
	screen.switch_handoff_pause = 0.0
	screen.switch_enter_duration = 0.01
	var switched_players: Array[int] = [screen.PLAYER]
	await screen._play_switch_handoff(switched_players, false)

	assert_almost_eq(float(screen.p1_heart_row._cur), 4.5, 0.001,
		"新角色开始进场时，顶部血条必须同步切到该角色的登场血量")
	assert_almost_eq(float(screen.p1_heart_row._extra), 1.0, 0.001,
		"护甲也必须跟随新角色更新，不能继续显示旧角色数据")
	assert_almost_eq(float(screen._prev_hp_disp[screen.PLAYER]), 4.5, 0.001,
		"换角色属于身份刷新，不应把新旧英雄血量差误判成一次受击")


func test_finisher_plays_both_submitted_actions_before_the_kill_flash() -> void:
	var screen = await _make_screen()
	await screen._play_battle_anims(
		ActionDef.Action.ATTACK, ActionDef.Action.CHARGE,
		[0, 2], [false, true])

	var winner_action: String = "finisher_action:%d:%d" % [
		screen.PLAYER, ActionDef.Action.ATTACK]
	var victim_action: String = "finisher_action:%d:%d" % [
		screen.AI, ActionDef.Action.CHARGE]
	assert_true(screen._resolution_phase_trace.has(winner_action),
		"黑白闪前保留胜利方动作")
	assert_true(screen._resolution_phase_trace.has(victim_action),
		"被斩杀方也必须播放本回合已提交动作，不能停在idle")
