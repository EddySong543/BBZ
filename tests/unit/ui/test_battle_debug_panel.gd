extends GutTest

const BattleDebugPanelScript := preload("res://src/ui/debug/battle_debug_panel.gd")


func test_next_hero_replaces_runtime_skill_and_clears_old_slot_state() -> void:
	var h14 := _hero_by_id("h14")
	var enemy := _hero_by_id("h01")
	assert_not_null(h14)
	assert_not_null(enemy)
	if h14 == null or enemy == null:
		return
	var battle := BattleCore.new()
	battle.setup([h14], [enemy], 6106)
	battle.hp[0][0] = BattleCore.HP_UNIT
	battle.shield[0][0] = 6
	battle.pending_damage[0][0] = 3
	battle.statuses[0][0] = {"legacy_marker": 1, "active_uses": 1}
	var old_skill := battle.get_skill(0, 0)
	assert_not_null(old_skill)

	var panel := BattleDebugPanelScript.new()
	add_child_autofree(panel)
	panel.setup(battle)
	var next_button := _button_with_text(panel, "我 下个英雄")
	assert_not_null(next_button)
	if next_button == null:
		return
	next_button.pressed.emit()

	assert_eq((battle.heroes[0][0] as HeroData).hero_id, "h15")
	assert_not_same(battle.get_skill(0, 0), old_skill,
			"debug replacement rebinds the actual HeroSkill component")
	assert_false(battle.get_skill(0, 0).can_defend(),
			"h15 runtime mechanism replaces h14 instead of changing only art/data")
	assert_eq(battle.statuses[0][0], {}, "old hero status cannot leak into replacement")
	assert_eq(battle.hp[0][0], battle.max_hp[0][0])
	assert_eq(battle.shield[0][0], 0)
	assert_eq(battle.pending_damage[0][0], 0)
	assert_eq(battle.selected_action[0], -1)


func test_scene6_legendary_debug_entry_is_fully_removed() -> void:
	var hero := _hero_by_id("h01")
	assert_not_null(hero)
	if hero == null:
		return
	var battle := BattleCore.new()
	battle.setup([hero], [hero.duplicate(true)], 6107)

	var scene6_panel := BattleDebugPanelScript.new()
	add_child_autofree(scene6_panel)
	scene6_panel.setup(battle)
	assert_null(_button_with_text(scene6_panel, "Scene6 熔岩巨剑"))
	assert_false(scene6_panel.has_signal("scene6_legendary_requested"))
	var panel_source := FileAccess.get_file_as_string(
			"res://src/ui/debug/battle_debug_panel.gd")
	var screen_source := FileAccess.get_file_as_string(
			"res://src/ui/battle_screen.gd")
	var interaction_source := FileAccess.get_file_as_string(
			"res://src/ui/components/scene6_click_interaction.gd")
	var secrets_source := FileAccess.get_file_as_string(
			"res://src/ui/components/scene6_magma_secrets.gd")
	for retired_marker: String in [
		"scene6_legendary_requested", "set_scene6_legendary_available",
		"_on_debug_scene6_legendary", "debug_force_legendary_at",
		"find_magma_point_near", "is_reveal_corridor_clear",
	]:
		assert_false(panel_source.contains(retired_marker)
				or screen_source.contains(retired_marker)
				or interaction_source.contains(retired_marker)
				or secrets_source.contains(retired_marker),
				"Scene6 临时巨剑测试链必须完整退役: %s" % retired_marker)


func _hero_by_id(hero_id: String) -> HeroData:
	for hero: HeroData in HeroData.create_launch_pool():
		if hero.hero_id == hero_id:
			return hero.duplicate(true) as HeroData
	return null


func _button_with_text(panel: Control, text: String) -> Button:
	for child: Node in panel.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
	return null
