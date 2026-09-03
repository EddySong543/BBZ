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
