extends GutTest

const Timeline := preload("res://src/battle/battle_resolution_timeline.gd")


func _item(step_id: String, item_id: String) -> Dictionary:
	return {
		"step_id": step_id,
		"kind": Timeline.STEP_ITEM,
		"item_id": item_id,
	}


func _action(step_id: String, action: String) -> Dictionary:
	return {
		"step_id": step_id,
		"kind": Timeline.STEP_ACTION,
		"action": action,
	}


func _timeline(p0: Array[Dictionary], p1: Array[Dictionary]) -> Timeline:
	var timeline: Timeline = Timeline.new()
	timeline.setup([p0, p1])
	return timeline


func _complete_next_column(timeline: Timeline) -> Dictionary:
	var column: Dictionary = timeline.begin_next_column()
	timeline.complete_current_column()
	return column


func test_steps_are_aligned_by_the_single_action_anchor() -> void:
	var p0: Array[Dictionary] = [
		_item("p0_item_a", "item_a"),
		_item("p0_item_b", "item_b"),
		_action("p0_action", "big_attack"),
		_item("p0_item_c", "item_c"),
	]
	var p1: Array[Dictionary] = [
		_item("p1_item_d", "item_d"),
		_action("p1_action", "attack"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	var first: Dictionary = _complete_next_column(timeline)
	var second: Dictionary = _complete_next_column(timeline)
	var anchor: Dictionary = _complete_next_column(timeline)
	var fourth: Dictionary = _complete_next_column(timeline)

	assert_eq(first["column"], 0)
	assert_eq(first["beat"], -2)
	assert_eq(first["steps"][0]["step_id"], "p0_item_a")
	assert_eq(first["steps"][1]["kind"], Timeline.STEP_WAIT)
	assert_eq(first["steps"][1]["reason"], Timeline.WAIT_REASON_ACTION_ALIGNMENT)
	assert_eq(second["column"], 1)
	assert_eq(second["beat"], -1)
	assert_eq(second["steps"][0]["step_id"], "p0_item_b")
	assert_eq(second["steps"][1]["step_id"], "p1_item_d")
	assert_eq(anchor["beat"], 0)
	assert_eq(anchor["steps"][0]["step_id"], "p0_action")
	assert_eq(anchor["steps"][1]["step_id"], "p1_action")
	assert_eq(fourth["beat"], 1)
	assert_eq(fourth["steps"][0]["step_id"], "p0_item_c")
	assert_eq(fourth["steps"][1]["kind"], Timeline.STEP_WAIT)
	assert_eq(fourth["steps"][1]["reason"], Timeline.WAIT_REASON_ACTION_ALIGNMENT)
	assert_false(timeline.has_next_column())


func test_request_wait_inserts_server_wait_before_target_remaining_step() -> void:
	var p0: Array[Dictionary] = [
		_action("p0_attack", "attack"),
		_item("p0_followup", "item_a"),
	]
	var p1: Array[Dictionary] = [
		_item("p1_item", "item_b"),
		_action("p1_action", "big_attack"),
		_item("p1_followup", "item_c"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	_complete_next_column(timeline)
	_complete_next_column(timeline)
	assert_true(timeline.request_wait(0, 1, "p0_attack"))
	var delayed: Dictionary = _complete_next_column(timeline)
	var resumed: Dictionary = _complete_next_column(timeline)
	var result: Dictionary = timeline.to_result()

	assert_eq(delayed["steps"][0]["step_id"], "p0_followup")
	assert_eq(delayed["steps"][1]["kind"], Timeline.STEP_WAIT)
	assert_eq(delayed["steps"][1]["player"], 1)
	assert_eq(delayed["steps"][1]["reason"], Timeline.WAIT_REASON_SEQUENCE_SHIFT)
	assert_eq(resumed["steps"][1]["step_id"], "p1_followup")
	assert_eq(result["events"][0]["id"], Timeline.EVENT_SEQUENCE_SHIFTED)
	assert_eq(result["events"][0]["column"], 1)
	assert_eq(result["events"][0]["source_player"], 0)
	assert_eq(result["events"][0]["player"], 1)
	assert_eq(result["events"][0]["insert_at"], 2)
	assert_eq(result["events"][0]["cause_step_id"], "p0_attack")
	assert_eq(result["events"][1]["id"], Timeline.EVENT_SEQUENCE_WAIT_EXECUTED)
	assert_eq(result["events"][1]["column"], 2)
	assert_eq(result["events"][1]["player"], 1)
	assert_eq(result["events"][1]["caused_by_event_id"], result["events"][0]["event_id"])


func test_wait_does_not_advance_target_cursor() -> void:
	var p0: Array[Dictionary] = [
		_action("p0_attack", "attack"),
		_item("p0_second", "item_a"),
	]
	var p1: Array[Dictionary] = [
		_item("p1_first", "item_b"),
		_action("p1_action", "charge"),
		_item("p1_second", "item_c"),
		_item("p1_third", "item_d"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	_complete_next_column(timeline)
	_complete_next_column(timeline)
	assert_true(timeline.request_wait(0, 1, "p0_attack"))
	var wait_column: Dictionary = _complete_next_column(timeline)
	var second_real_column: Dictionary = _complete_next_column(timeline)
	var third_real_column: Dictionary = _complete_next_column(timeline)

	assert_eq(wait_column["steps"][1]["kind"], Timeline.STEP_WAIT)
	assert_eq(second_real_column["steps"][1]["step_id"], "p1_second")
	assert_eq(third_real_column["steps"][1]["step_id"], "p1_third")


func test_same_column_requests_insert_symmetric_waits() -> void:
	var p0: Array[Dictionary] = [
		_action("p0_attack", "attack"),
		_item("p0_after", "item_a"),
	]
	var p1: Array[Dictionary] = [
		_action("p1_attack", "attack"),
		_item("p1_after", "item_b"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	_complete_next_column(timeline)
	assert_true(timeline.request_wait(0, 1, "p0_attack"))
	assert_true(timeline.request_wait(1, 0, "p1_attack"))
	var waits: Dictionary = _complete_next_column(timeline)
	var resumed: Dictionary = _complete_next_column(timeline)
	var result: Dictionary = timeline.to_result()

	assert_eq(waits["steps"][0]["kind"], Timeline.STEP_WAIT)
	assert_eq(waits["steps"][1]["kind"], Timeline.STEP_WAIT)
	assert_eq(resumed["steps"][0]["step_id"], "p0_after")
	assert_eq(resumed["steps"][1]["step_id"], "p1_after")
	assert_eq(result["events"].filter(
		func(event: Dictionary) -> bool:
			return event["id"] == Timeline.EVENT_SEQUENCE_SHIFTED
	).size(), 2)
	assert_eq(result["events"].filter(
		func(event: Dictionary) -> bool:
			return event["id"] == Timeline.EVENT_SEQUENCE_WAIT_EXECUTED
	).size(), 2)


func test_request_wait_is_ignored_when_target_has_no_remaining_step() -> void:
	var p0: Array[Dictionary] = [
		_action("p0_attack", "attack"),
		_item("p0_after", "item_a"),
	]
	var p1: Array[Dictionary] = [
		_action("p1_only", "defend"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	_complete_next_column(timeline)
	assert_false(timeline.request_wait(0, 1, "p0_attack"))
	var next_column: Dictionary = _complete_next_column(timeline)
	var result: Dictionary = timeline.to_result()

	assert_eq(next_column["steps"][1]["kind"], Timeline.STEP_WAIT)
	assert_eq(next_column["steps"][1]["reason"], Timeline.WAIT_REASON_ACTION_ALIGNMENT)
	assert_eq(result["events"], [])


func test_result_preserves_submitted_step_ids_order_and_is_detached_from_inputs() -> void:
	var p0: Array[Dictionary] = [
		_item("p0_a", "item_a"),
		_item("p0_b", "item_b"),
		_action("p0_c", "attack"),
	]
	var p1: Array[Dictionary] = [
		_action("p1_a", "charge"),
	]
	var timeline: Timeline = _timeline(p0, p1)
	p0[0]["step_id"] = "mutated_outside"

	while timeline.has_next_column():
		_complete_next_column(timeline)
	var result: Dictionary = timeline.to_result()
	var submitted_p0: Array = result["submitted_sequences"][0]

	assert_eq(submitted_p0.map(
		func(step: Dictionary) -> String:
			return String(step["step_id"])
	), ["p0_a", "p0_b", "p0_c"])
	result["submitted_sequences"][0][0]["step_id"] = "mutated_result"
	assert_eq(timeline.to_result()["submitted_sequences"][0][0]["step_id"], "p0_a")


func test_shift_event_is_attached_to_source_column_and_wait_event_to_wait_column() -> void:
	var p0: Array[Dictionary] = [
		_action("p0_attack", "attack"),
		_item("p0_after", "item_a"),
	]
	var p1: Array[Dictionary] = [
		_item("p1_first", "item_b"),
		_action("p1_after", "defend"),
		_item("p1_followup", "item_c"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	_complete_next_column(timeline)
	_complete_next_column(timeline)
	assert_true(timeline.request_wait(0, 1, "p0_attack"))
	_complete_next_column(timeline)
	var columns: Array = timeline.to_result()["resolved_columns"]

	assert_eq(columns[1]["events"].size(), 1)
	assert_eq(columns[1]["events"][0]["id"], Timeline.EVENT_SEQUENCE_SHIFTED)
	assert_eq(columns[2]["events"].size(), 1)
	assert_eq(columns[2]["events"][0]["id"], Timeline.EVENT_SEQUENCE_WAIT_EXECUTED)


func test_cancel_remaining_keeps_completed_columns_and_skips_alignment_waits() -> void:
	var p0: Array[Dictionary] = [
		_item("p0_setup", "item_a"),
		_action("p0_action", "attack"),
		_item("p0_after", "item_b"),
	]
	var p1: Array[Dictionary] = [
		_action("p1_action", "charge"),
		_item("p1_after", "item_c"),
	]
	var timeline: Timeline = _timeline(p0, p1)

	_complete_next_column(timeline)
	_complete_next_column(timeline)
	var cancelled: Array[Dictionary] = timeline.cancel_remaining(
		"active_hero_died", [1])
	var result: Dictionary = timeline.to_result()

	assert_false(timeline.has_next_column())
	assert_eq(result["resolved_columns"].size(), 2)
	assert_eq(cancelled.map(
		func(event: Dictionary) -> String:
			return String(event.get("step_id", ""))
	), ["p0_after", "p1_after"])
	assert_eq((result["events"] as Array).filter(
		func(event: Dictionary) -> bool:
			return String(event.get("id", "")) == Timeline.EVENT_SEQUENCE_TRUNCATED
	).size(), 1)
	assert_false((result["events"] as Array).any(
		func(event: Dictionary) -> bool:
			return String(event.get("reason", "")) == Timeline.WAIT_REASON_ACTION_ALIGNMENT
	), "系统补齐的对齐等待不属于被取消的玩家步骤")
	assert_eq(result["submitted_sequences"][0][2]["step_id"], "p0_after",
		"截断不能改写玩家原始提交")
