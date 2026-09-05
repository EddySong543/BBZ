extends GutTest


func test_local_battle_uses_v2_pool_and_ai_submits_through_same_validator() -> void:
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen1.tscn") as PackedScene
	var screen = packed.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.battle.item_v2_enabled)
	assert_eq(screen.battle.battle_backpacks[0].size(), 20)
	assert_eq(screen.battle.battle_backpacks[1].size(), 20)
	assert_false(screen.battle.battle_backpacks[0].any(
		func(entry: Dictionary) -> bool:
			return String(entry.get("item_id", "")).begins_with("t1_")),
		"当前生产背包只进入新版启用名单")
	for player: int in [0, 1]:
		for slot: int in range(BattleCore.SLOT_COUNT):
			assert_eq(screen.battle.slot_state(player, slot), BattleCore.SlotState.EMPTY)

	screen.state = screen.State.PLAYER_SELECT
	screen._item_v2_ai_draw()
	assert_eq(screen.battle.item_v2_draw_used_turn[1], screen.battle.turn_number)
	assert_eq(screen.battle.slot_state(1, 0), BattleCore.SlotState.CHARGING)
	assert_false(screen.battle.slot_ready(1, 0), "AI取得结果同样锁定到下一回合")
	var sequence: Array[Dictionary] = screen._item_v2_ai_sequence(1)
	assert_true(screen.battle.validate_item_v2_command_sequence(1, sequence))


func test_v2_enemy_sequence_is_locked_and_exposed_before_player_submit() -> void:
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen1.tscn") as PackedScene
	var screen = packed.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.battle.item_v2_command_sequences[1] = []

	screen._start_player_select()
	assert_eq(screen.state, screen.State.PLAYER_SELECT)
	var locked: Array = screen.battle.item_v2_command_sequences[1].duplicate(true)
	assert_false(locked.is_empty())
	assert_true(screen._enemy_sequence_label.visible)
	assert_true(screen._enemy_sequence_label.text.begins_with("敌方序列："))
	assert_true(screen._enemy_sequence_label.text.contains("0拍"))
	assert_true(screen._enemy_sequence_label.get_global_rect().end.y \
		<= screen._command_order_strip.get_global_rect().position.y,
		"敌方公开序列必须位于玩家编排槽上方，不能遮住拖拽顺序")
	assert_false(screen.battle.submit_item_v2_command_sequence(1, [
		{"kind": "action", "action": ActionDef.Action.DEFEND, "target": -1}]),
		"敌方一经公开锁定，普通提交入口不能覆写")

	screen._turn_command_queue.append({"kind": "action", "ordinal": 0})
	assert_true(screen._lock_item_v2_enemy_sequence())
	assert_eq(screen.battle.item_v2_command_sequences[1], locked,
		"玩家开始规划后再次检查锁定状态，不得让敌方重算")
