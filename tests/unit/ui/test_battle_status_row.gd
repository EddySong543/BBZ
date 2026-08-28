extends GutTest

const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const TUNING_LAB_PATH := "res://src/ui/debug/buff_tuning_lab.tscn"
const BattleStatusRowScript := preload("res://src/ui/components/battle_status_row.gd")


func _entry(effect_id: StringName, value: int) -> Dictionary:
	var entry: Dictionary = EffectCatalog.get_by_id(effect_id)
	entry["value"] = value
	return entry


func test_status_row_reflows_around_the_same_center_when_count_changes() -> void:
	var row: Control = BattleStatusRowScript.new()
	add_child_autofree(row)
	assert_eq(row.slot_gap, 0.0)
	assert_eq(row.count_font_size, 12)
	assert_eq(row.count_symbol_gap, 2.0)
	assert_true(row.use_per_icon_count_offsets)
	assert_eq(row.poison_count_offset, Vector2(0.0, 20.0))
	assert_eq(row.vulnerable_count_offset, Vector2(-2.0, 20.0))
	assert_eq(row.sword_qi_count_offset, Vector2(-6.0, 20.0),
			"正式组件默认值必须复刻临时场景的最终手调参数")
	row.call("refresh", [_entry(&"poison", 1)])
	var one_rects: Array[Rect2] = row.call("debug_slot_rects")
	assert_eq(one_rects.size(), 1)
	assert_almost_eq(float(row.call("icon_alignment_center_x")), 17.0, 0.01,
			"单个效果以34px图标中心对齐，右侧数字不参与")
	assert_ne(float(row.call("icon_alignment_center_x")), row.size.x * 0.5,
			"数字仍保留防遮挡排版宽度，但不得再决定战斗锚点")
	assert_eq(row.call("effect_ids"), [&"poison"])

	row.call("refresh", [_entry(&"poison", 1), _entry(&"vulnerable", 2)])
	var two_rects: Array[Rect2] = row.call("debug_slot_rects")
	assert_eq(two_rects.size(), 2)
	var two_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(float(row.call("icon_alignment_center_x")),
			two_icon_rect.get_center().x, 0.01,
			"从一个增加到两个效果时只使用图标联合边界重新居中")
	assert_eq(row.call("effect_ids"), [&"poison", &"vulnerable"])
	assert_true(row.find_children("*", "ColorRect", true, false).is_empty(),
			"战斗状态整行不得残留任何底板或边框填充")
	for slot: Node in row.get_children():
		assert_false(slot.has_node("Border"),
				"战斗状态直接显示图标，不保留效果色边框")
		assert_false(slot.has_node("Plate"),
				"战斗状态直接显示图标，不保留黑色底板")
		assert_false(slot.has_node("CountPlate"),
				"层数只以描边数字叠在图标上，不保留黑色数字底板")
		assert_true(slot.has_node("Icon"))
		assert_true(slot.has_node("Count"))
	for icon: TextureRect in row.call("debug_icons"):
		assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
				"效果素材必须使用点采样")
		assert_true(icon.texture is AtlasTexture,
				"效果素材先裁掉不一致的透明留白，再缩入统一图标格")
		assert_eq(icon.size, Vector2(34.0, 34.0),
				"每种 buff 的裁边素材都占用相同的 34px 可见框")
		assert_eq(icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
				"毒素、脆弱、剑气共用同一光学框，但不得被强拉成相同长宽比")

	row.call("refresh", [_entry(&"poison", 3), _entry(&"vulnerable", 1),
			_entry(&"sword_qi", 4)])
	var formal_sword_icon := row.get_node("Status_sword_qi/Icon") as TextureRect
	assert_almost_eq(formal_sword_icon.size.x, 40.8, 0.001,
			"正式战斗组件默认将纵向窄剑气等比放大20%")
	assert_almost_eq(formal_sword_icon.size.y, 40.8, 0.001)
	for slot: Control in row.get_children():
		var icon := slot.get_node("Icon") as TextureRect
		var icon_shadow := slot.get_node("IconShadow") as TextureRect
		var count := slot.get_node("Count") as Control
		assert_not_null(icon_shadow, "每个 buff 图标都有同形像素阴影")
		assert_eq(icon_shadow.texture, icon.texture)
		assert_eq(icon_shadow.position, icon.position + row.icon_shadow_offset)
		assert_eq(icon_shadow.self_modulate, row.icon_shadow_color)
		var effect_id := StringName(slot.get_meta("effect_id"))
		assert_true(count.visible, "毒素、按回合脆弱与剑气都显示当前数值")
		var prefix := count.get_node("Prefix") as Label
		var value_label := count.get_node("Value") as Label
		var expected_values := {
			&"poison": "3", &"vulnerable": "1", &"sword_qi": "4"}
		assert_eq(prefix.text, "x", "可计数 buff 使用小写 x 前缀")
		assert_eq(value_label.text, expected_values[effect_id])
		assert_almost_eq(value_label.position.x - prefix.get_rect().end.x,
				row.count_symbol_gap, 0.01, "x 与数字使用可调像素间距")
		assert_true(prefix.get_theme_font("font") is FontVariation)
		assert_almost_eq(
				(prefix.get_theme_font("font") as FontVariation).variation_embolden,
				0.6, 0.001, "层数沿用顶部数字的加粗强度")
		assert_eq(prefix.get_theme_color("font_shadow_color"),
				Color(0.0, 0.0, 0.0, 0.32))
		assert_eq(prefix.get_theme_constant("shadow_offset_x"), 1)
		assert_eq(prefix.get_theme_constant("shadow_offset_y"), 1)
		assert_eq(prefix.get_theme_constant("shadow_outline_size"), 0)
	row.call("refresh", [_entry(&"poison", 4), _entry(&"vulnerable", 1),
			_entry(&"sword_qi", 4)])
	var poison_count := row.get_node("Status_poison/Count") as Control
	assert_lt(poison_count.scale.x, 1.0,
			"已有 buff 层数变化时，外置数字以短促弹跳提示变化")
	await get_tree().create_timer(0.18).timeout
	assert_almost_eq(poison_count.scale.x, 1.0, 0.01,
			"层数反馈在 0.14 秒后稳定回到原尺寸")

	var three_entries: Array[Dictionary] = [
		_entry(&"poison", 1), _entry(&"vulnerable", 2), _entry(&"sword_qi", 4)]
	row.call("refresh", three_entries)
	var three_rects: Array[Rect2] = row.call("debug_slot_rects")
	assert_eq(three_rects.size(), 3)
	var three_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(float(row.call("icon_alignment_center_x")),
			three_icon_rect.get_center().x, 0.01,
			"三个效果仍只以可见图标联合边界确定中心轴")
	row.visible = false
	row.call("refresh", three_entries)
	assert_true(row.visible,
			"换人交接中暂时隐藏后，即使新旧效果值相同也要恢复显示")


func test_only_new_buffs_play_the_restrained_enter_motion() -> void:
	var row: Control = BattleStatusRowScript.new()
	add_child_autofree(row)
	row.call("refresh", [_entry(&"poison", 1)])
	var new_poison := row.get_node("Status_poison") as Control
	assert_true(bool(new_poison.get_meta("enter_motion_played", false)))
	assert_almost_eq(new_poison.position.y, row.enter_lift, 0.01)
	assert_almost_eq(new_poison.scale.x, row.enter_scale, 0.01)
	assert_almost_eq(new_poison.modulate.a, 0.0, 0.01)
	await get_tree().create_timer(row.enter_duration + 0.04).timeout
	assert_almost_eq(new_poison.position.y, 0.0, 0.01)
	assert_almost_eq(new_poison.scale.x, 1.0, 0.01)
	assert_almost_eq(new_poison.modulate.a, 1.0, 0.01)

	row.call("refresh", [_entry(&"poison", 2)])
	var updated_poison := row.get_node("Status_poison") as Control
	assert_false(bool(updated_poison.get_meta("enter_motion_played", false)),
			"已有 buff 仅更新数字，不得重播整枚图标入场")
	assert_eq(updated_poison.position, Vector2.ZERO)
	assert_eq(updated_poison.scale, Vector2.ONE)
	assert_almost_eq(updated_poison.modulate.a, 1.0, 0.01)

	row.call("refresh", [_entry(&"poison", 2), _entry(&"vulnerable", 2)])
	assert_false(bool((row.get_node("Status_poison") as Control).get_meta(
			"enter_motion_played", false)))
	assert_true(bool((row.get_node("Status_vulnerable") as Control).get_meta(
			"enter_motion_played", false)),
			"新增第二个 buff 时只动画新图标")


func test_buff_tuning_lab_uses_the_real_component_and_live_tuning_geometry() -> void:
	var packed := load(TUNING_LAB_PATH) as PackedScene
	assert_not_null(packed, "临时 Buff 调整场景必须可直接打开或 F6 运行")
	var lab := packed.instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var preview := lab.get_node("BuffPreview") as BattleStatusRow
	assert_true(preview.preview_enabled)
	assert_eq(preview.slot_gap, 0.0)
	assert_eq(preview.poison_count_offset, Vector2(0.0, 20.0))
	assert_eq(preview.vulnerable_count_offset, Vector2(-2.0, 20.0))
	assert_eq(preview.sword_qi_count_offset, Vector2(-6.0, 20.0),
			"临时场景保留用户在 Inspector 中保存的独立数字偏移")
	assert_eq(preview.count_symbol_gap, 2.0)
	assert_eq(preview.count_shadow_color, Color(0.0, 0.0, 0.0, 0.32))
	assert_eq(preview.effect_ids(), [&"poison", &"vulnerable", &"sword_qi"],
			"调试场景直接预览正式毒素、脆弱、剑气组件")
	assert_almost_eq(preview.position.x + float(preview.call(
			"icon_alignment_center_x")), lab.preview_center.x, 0.51,
			"临时场景与正式战斗都忽略数字，只用图标联合边界居中")
	preview.icon_box_size = Vector2(42.0, 38.0)
	preview.count_offset = Vector2(5.0, 12.0)
	preview.use_per_icon_count_offsets = true
	preview.poison_count_offset = Vector2(2.0, 14.0)
	preview.vulnerable_count_offset = Vector2(1.0, 13.0)
	preview.sword_qi_count_offset = Vector2(-4.0, 11.0)
	preview.count_font_size = 17
	preview.count_symbol_gap = 6.0
	preview.sword_qi_icon_scale = 1.25
	preview.call("_refresh_editor_preview")
	var poison_icon := preview.get_node("Status_poison/Icon") as TextureRect
	assert_eq(poison_icon.size, Vector2(42.0, 38.0),
			"Inspector 调整图标框后真实组件立即重建")
	var sword_icon := preview.get_node("Status_sword_qi/Icon") as TextureRect
	assert_eq(sword_icon.size, Vector2(52.5, 47.5),
			"纵向剑气可用独立等比滑杆补偿较小的可见面积")
	var poison_count := preview.get_node("Status_poison/Count") as Control
	assert_eq(poison_count.position, Vector2(44.0, 14.0))
	var poison_prefix := poison_count.get_node("Prefix") as Label
	var poison_value := poison_count.get_node("Value") as Label
	assert_eq(poison_prefix.get_theme_font_size("font_size"), 17)
	assert_eq(poison_prefix.text, "x")
	assert_eq(poison_value.text, "3")
	assert_almost_eq(poison_value.position.x - poison_prefix.get_rect().end.x,
			6.0, 0.01)
	var vulnerable_count := preview.get_node("Status_vulnerable/Count") as Control
	assert_eq(vulnerable_count.position, Vector2(43.0, 13.0))
	assert_eq((vulnerable_count.get_node("Value") as Label).text, "2",
			"脆弱预览显示当前剩余回合数")
	var sword_count := preview.get_node("Status_sword_qi/Count") as Control
	assert_eq(sword_count.position, Vector2(38.0, 11.0),
			"纵向剑气拥有独立光学修正，不需要旋转素材来迁就数字")
	var sword_font := (sword_count.get_node("Value") as Label).get_theme_font(
			"font") as FontVariation
	assert_not_null(sword_font)
	assert_eq(sword_font.base_font.resource_path,
			"res://assets/font/zlabs_pixel_ui.tres",
			"编辑器预览直接加载正式字体资源，不再依赖运行时 Autoload")


func test_core_status_keys_map_to_catalog_ids_in_a_stable_order() -> void:
	var entries: Array[Dictionary] = EffectCatalog.battle_status_entries({
		"jianqi": 4,
		"poison": 1,
		"vuln": 2,
		"silenced": 9,
	})
	assert_eq(entries.map(func(entry: Dictionary) -> StringName:
		return StringName(entry.id)), [&"poison", &"vulnerable", &"sword_qi"])
	assert_eq(entries.map(func(entry: Dictionary) -> int:
		return int(entry.value)), [1, 2, 4])
	assert_eq(entries.map(func(entry: Dictionary) -> bool:
		return bool(entry.get("show_stack_count", false))), [true, true, true],
			"毒素、按回合脆弱与剑气都向战斗 UI 提供数值")
	assert_true(EffectCatalog.battle_status_entries({
		"poison": 0, "vuln": -1, "jianqi": 0}).is_empty(),
			"零值、负值和无关状态不生成战斗状态图标")


func test_battle_status_rows_anchor_after_player_names_and_hide_on_death() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen._battle_status_rows.size(), 2,
			"双方出战英雄各有一个独立的 HUD 效果队列")
	var p1_anchor := screen.get_node("P1Hud/P1StatusAnchor") as Control
	var p2_anchor := screen.get_node("P2Hud/P2StatusAnchor") as Control
	assert_not_null(p1_anchor, "P1 状态锚点必须能在共享战斗场景中可视化调整")
	assert_not_null(p2_anchor, "P2 状态锚点必须能在共享战斗场景中可视化调整")
	assert_almost_eq(p1_anchor.position.x,
			screen.p1_coin_row.position.x
					+ 3.0 * (screen.p1_coin_row.pip_size + screen.p1_coin_row.spacing),
			0.1, "P1 默认从第四个能量点起始处显示 Buff")
	assert_almost_eq(p2_anchor.position.x, screen.SCREEN_W - p1_anchor.position.x,
			0.1, "P2 状态锚点必须镜像 P1")
	assert_almost_eq(p1_anchor.position.y,
			screen.p1_player_id.position.y + screen.p1_player_id.size.y * 0.5,
			0.1, "Buff 与玩家名共用垂直中心线")

	var player: int = screen.PLAYER
	var slot: int = screen.battle.active_index[player]
	screen.battle.set_status(player, slot, "poison", 1)
	screen._update_all()
	await get_tree().process_frame
	var row: Control = screen._battle_status_rows[player]
	assert_true(row.visible)
	assert_eq(row.get_parent(), p1_anchor)
	assert_eq(row.call("effect_ids"), [&"poison"])
	var one_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(row.position.x + one_icon_rect.position.x, 0.0, 0.51,
			"P1 从锚点向右展开，左边界只取图标而不取数字")
	assert_almost_eq(row.position.y + one_icon_rect.get_center().y, 0.0, 0.51,
			"状态图标中心与玩家名中心对齐")
	var initial_position := row.global_position
	screen.p1_char_display.offset_transform_position = Vector2(18.0, 6.0)
	screen._position_battle_status_rows()
	assert_eq(row.global_position, initial_position,
			"角色攻击或换人演出不得再拖动固定 HUD 状态栏")
	screen.p1_char_display.offset_transform_position = Vector2.ZERO

	screen.battle.set_status(player, slot, "vuln", 2)
	screen._update_all()
	await get_tree().process_frame
	assert_eq(row.call("effect_ids"), [&"poison", &"vulnerable"])
	var vulnerable_count := row.get_node("Status_vulnerable/Count") as Control
	assert_true(vulnerable_count.visible)
	assert_eq((vulnerable_count.get_node("Value") as Label).text, "2",
			"正式战斗中的脆弱显示当前回合数")
	var two_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(row.position.x + two_icon_rect.position.x, 0.0, 0.51,
			"新增第二个效果后仍忽略数字宽度，从玩家名后固定起点展开")

	var enemy: int = screen.AI
	var enemy_slot: int = screen.battle.active_index[enemy]
	screen.battle.set_status(enemy, enemy_slot, "jianqi", 4)
	screen._update_all()
	await get_tree().process_frame
	var enemy_row: Control = screen._battle_status_rows[enemy]
	assert_eq(enemy_row.call("effect_ids"), [&"sword_qi"])
	assert_eq(enemy_row.get_parent(), p2_anchor)
	var enemy_icon_rect: Rect2 = enemy_row.call("debug_icon_alignment_rect")
	assert_almost_eq(enemy_row.position.x + enemy_icon_rect.end.x, 0.0, 0.51,
			"P2 从镜像锚点向左展开，右边界只取图标而不取数字")
	assert_almost_eq(enemy_row.position.y + enemy_icon_rect.get_center().y,
			0.0, 0.51, "P2 状态图标同样与玩家名中心对齐")

	screen.battle.hp[player][slot] = 0
	screen._update_all()
	assert_false(row.visible, "出战英雄死亡时隐藏对应 HUD 状态图标")
	BattleSetup.reset()
