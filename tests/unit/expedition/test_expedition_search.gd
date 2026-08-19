extends GutTest

## 远征逐件搜索与容器系统行为锁定测试。
const SearchState := preload("res://src/expedition/expedition_search_state.gd")


func _item(item_id: String, shape: Array) -> Dictionary:
	return {
		"id": item_id,
		"name": item_id,
		"cat": "gold",
		"shape": shape.duplicate(),
	}


func _shape(count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x: int in count:
		result.append(Vector2i(x, 0))
	return result


func test_search_is_hidden_and_advances_one_turn_per_occupied_cell() -> void:
	var search: SearchState = SearchState.new()
	assert_true(search.register_container("chest-a", [_item("large", _shape(3)), _item("small", _shape(1))]))
	var opened: Dictionary = search.open_container("chest-a")
	assert_eq((opened["container"]["visible_items"] as Array).size(), 0)
	assert_eq(int(opened["container"]["hidden_count"]), 2)

	var started: Dictionary = search.start_next_item()
	assert_eq(int(started["search"]["required_turns"]), 3)
	for expected_progress: int in [1, 2]:
		var step: Dictionary = search.advance_turn()
		assert_eq(int(step["turn_cost"]), 1)
		assert_eq(int(step["progress_turns"]), expected_progress)
		assert_false(bool(step["completed"]))
	var revealed: Dictionary = search.advance_turn()
	assert_true(bool(revealed["completed"]))
	assert_eq(String(revealed["revealed_item"]["id"]), "large")
	assert_eq((search.open_snapshot()["visible_items"] as Array).size(), 1)
	assert_eq(String(search.advance_turn()["reason"]), "no_active_search", "完成后不能自动搜索下一件")


func test_next_item_requires_explicit_start_and_exhausted_reopen_is_free() -> void:
	var search: SearchState = SearchState.new()
	search.register_container("bag", [_item("one", _shape(1)), _item("two", _shape(1))])
	search.open_container("bag")
	search.start_next_item()
	search.advance_turn()
	assert_eq(int(search.open_snapshot()["hidden_count"]), 1)
	assert_eq(String(search.advance_turn()["reason"]), "no_active_search")
	assert_true(bool(search.start_next_item()["ok"]))
	search.advance_turn()

	var reopened: Dictionary = search.open_container("bag")
	assert_eq(int(reopened["turn_cost"]), 0)
	assert_true(bool(reopened["container"]["exhausted"]))
	assert_eq((reopened["container"]["visible_items"] as Array).size(), 2)
	assert_eq(String(search.start_next_item()["reason"]), "container_exhausted")


func test_interrupt_leave_and_battle_restore_keep_partial_progress() -> void:
	var search: SearchState = SearchState.new()
	search.register_container("body", [_item("three-cell", _shape(3))])
	search.open_container("body")
	search.start_next_item()
	search.advance_turn()
	search.close_container("left_container")

	search.open_container("body")
	var resumed: Dictionary = search.start_next_item()
	assert_eq(int(resumed["search"]["progress_turns"]), 1)
	search.advance_turn()
	search.interrupt("battle")
	var save: Dictionary = search.serialize()
	var restored: SearchState = SearchState.new()
	assert_true(restored.restore(save))
	var after_battle: Dictionary = restored.start_next_item()
	assert_eq(int(after_battle["search"]["progress_turns"]), 2)
	assert_true(bool(restored.advance_turn()["completed"]))


func test_new_enemy_pauses_once_but_different_enemy_pauses_again() -> void:
	var search: SearchState = SearchState.new()
	search.register_container("cache", [_item("long", _shape(4))])
	search.open_container("cache")
	search.start_next_item()
	search.advance_turn()

	var first: Dictionary = search.notify_new_enemy("enemy-a", 3)
	assert_true(bool(first["paused"]))
	assert_eq(int(first["remaining_turns"]), 3)
	assert_eq(String(search.advance_turn()["reason"]), "enemy_pause_pending")
	assert_true(bool(search.resolve_enemy_pause(true)["ok"]))
	assert_false(bool(search.notify_new_enemy("enemy-a", 2)["paused"]), "强行继续后同敌人不得反复暂停")
	assert_true(bool(search.notify_new_enemy("enemy-b", 5)["paused"]), "新的敌人仍应暂停")
	var stopped: Dictionary = search.resolve_enemy_pause(false)
	assert_eq(String(stopped["action"]), "interrupt_search")

	var resumed: Dictionary = search.start_next_item()
	assert_eq(int(resumed["search"]["progress_turns"]), 1)


func test_take_revealed_costs_one_action_and_hidden_item_cannot_be_taken() -> void:
	var search: SearchState = SearchState.new()
	search.register_container("crate", [_item("loot", _shape(1))])
	search.open_container("crate")
	var hidden_entry: String = String(search.start_next_item()["search"]["entry_id"])
	assert_eq(String(search.take_revealed(hidden_entry)["reason"]), "item_hidden")
	search.advance_turn()

	var taken: Dictionary = search.take_revealed(hidden_entry)
	assert_true(bool(taken["ok"]))
	assert_eq(int(taken["turn_cost"]), 1)
	assert_eq(String(taken["action"]), "take_to_backpack")
	assert_eq(String(taken["item"]["id"]), "loot")
	assert_eq((search.open_snapshot()["visible_items"] as Array).size(), 0)


func test_container_accepts_backpack_item_as_immediately_visible() -> void:
	var search: SearchState = SearchState.new()
	search.register_container("sack", [])
	search.open_container("sack")
	var returned: Dictionary = search.return_from_backpack(_item("returned", _shape(2)))
	assert_true(bool(returned["ok"]))
	assert_eq(int(returned["turn_cost"]), 1)
	var visible: Array = search.open_snapshot()["visible_items"]
	assert_eq(visible.size(), 1)
	assert_eq(String(visible[0]["item"]["id"]), "returned")
	assert_true(bool(search.open_snapshot()["exhausted"]), "放回物不应重新变成隐藏搜索物")


func test_inputs_outputs_and_save_snapshots_are_deep_copied() -> void:
	var source_item: Dictionary = _item("original", _shape(1))
	var search: SearchState = SearchState.new()
	search.register_container("safe", [source_item])
	source_item["name"] = "外部污染"
	search.open_container("safe")
	search.start_next_item()
	var result: Dictionary = search.advance_turn()
	assert_eq(String(result["revealed_item"]["name"]), "original")

	var snapshot: Dictionary = search.open_snapshot()
	snapshot["visible_items"][0]["item"]["name"] = "UI污染"
	assert_eq(String(search.open_snapshot()["visible_items"][0]["item"]["name"]), "original")
	var save: Dictionary = search.serialize()
	save["containers"]["safe"]["entries"][0]["item"]["name"] = "存档污染"
	assert_eq(String(search.open_snapshot()["visible_items"][0]["item"]["name"]), "original")
