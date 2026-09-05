class_name BattleResolutionTimeline
extends RefCounted

## Pure two-player sequence scheduler for authoritative battle resolution.
## Submitted steps stay immutable. Each side's single public action is aligned to
## the shared beat 0; pre/post steps keep their distance from that action. Core
## effects may schedule a synthetic wait after a completed column without
## advancing that player's execution-step cursor.

const PLAYER_COUNT: int = 2

const STEP_ITEM: String = "item"
const STEP_ACTION: String = "action"
const STEP_WAIT: String = "wait"

const WAIT_REASON_ACTION_ALIGNMENT: String = "action_alignment"
const WAIT_REASON_SEQUENCE_SHIFT: String = "sequence_shift"
const EVENT_SEQUENCE_SHIFTED: String = "sequence_shifted"
const EVENT_SEQUENCE_WAIT_EXECUTED: String = "sequence_wait_executed"
const EVENT_SEQUENCE_TRUNCATED: String = "sequence_truncated"
const EVENT_SEQUENCE_STEP_CANCELLED: String = "sequence_step_cancelled"

var _submitted_sequences: Array[Array] = [[], []]
var _execution_sequences: Array[Array] = [[], []]
var _cursors: Array[int] = [0, 0]
var _pending_waits: Array[Array] = [[], []]
var _resolved_columns: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _current_column: Dictionary = {}
var _column_open: bool = false
var _accepting_wait_requests: bool = false
var _next_event_id: int = 1
var _action_anchor_column: int = -1


func setup(submitted_sequences: Array) -> void:
	_reset()
	if submitted_sequences.size() != PLAYER_COUNT:
		push_error("BattleResolutionTimeline requires exactly two submitted sequences")
		return
	_submitted_sequences[0] = _copy_sequence(submitted_sequences[0] as Array)
	_submitted_sequences[1] = _copy_sequence(submitted_sequences[1] as Array)

	var action_indices: Array[int] = [
		_find_single_action_index(_submitted_sequences[0]),
		_find_single_action_index(_submitted_sequences[1]),
	]
	if action_indices[0] < 0 or action_indices[1] < 0:
		push_error("BattleResolutionTimeline requires exactly one action step per player")
		return
	_build_execution_sequences(action_indices)


func has_next_column() -> bool:
	if _column_open:
		return true
	for player: int in range(PLAYER_COUNT):
		if not _pending_waits[player].is_empty():
			return true
		if _has_unresolved_execution_step(player):
			return true
	return false


func begin_next_column() -> Dictionary:
	if _column_open:
		push_error("BattleResolutionTimeline current column must be completed first")
		return {}
	if not has_next_column():
		return {}

	_accepting_wait_requests = false
	var column_index: int = _resolved_columns.size()
	var steps: Array = [null, null]
	var column_events: Array[Dictionary] = []

	for player: int in range(PLAYER_COUNT):
		if not _pending_waits[player].is_empty():
			var wait_request: Dictionary = _pending_waits[player].pop_front()
			var wait_step: Dictionary = _make_wait_step(player, column_index, wait_request)
			steps[player] = wait_step
			var wait_event: Dictionary = _make_wait_executed_event(
				player, column_index, wait_step, wait_request
			)
			column_events.append(wait_event)
			_events.append(wait_event.duplicate(true))
		elif _has_unresolved_execution_step(player):
			var sequence: Array = _execution_sequences[player]
			steps[player] = (sequence[_cursors[player]] as Dictionary).duplicate(true)
			_cursors[player] += 1

	_current_column = {
		"column": column_index,
		"beat": column_index - _action_anchor_column,
		"steps": steps,
		"events": column_events,
	}
	_column_open = true
	return _current_column.duplicate(true)


func complete_current_column() -> Dictionary:
	if not _column_open:
		push_error("BattleResolutionTimeline has no open column to complete")
		return {}
	var completed: Dictionary = _current_column.duplicate(true)
	_resolved_columns.append(completed)
	_current_column = {}
	_column_open = false
	_accepting_wait_requests = true
	return completed.duplicate(true)


func request_wait(source_player: int, target_player: int, cause_step_id: String) -> bool:
	if not _accepting_wait_requests or _column_open or _resolved_columns.is_empty():
		return false
	if not _is_player(source_player) or not _is_player(target_player):
		return false
	if source_player == target_player:
		return false
	var source_column_index: int = _resolved_columns.size() - 1
	if source_column_index < _action_anchor_column:
		return false
	if not _has_unresolved_real_step(target_player):
		return false

	var shift_event_id: int = _take_event_id()
	var insert_at: int = source_column_index + 1 + _pending_waits[target_player].size()
	var shift_event: Dictionary = {
		"id": EVENT_SEQUENCE_SHIFTED,
		"event_id": shift_event_id,
		"column": source_column_index,
		"source_player": source_player,
		"player": target_player,
		"insert_at": insert_at,
		"amount": 1,
		"cause_step_id": cause_step_id,
	}
	var wait_request: Dictionary = {
		"source_player": source_player,
		"cause_step_id": cause_step_id,
		"caused_by_event_id": shift_event_id,
	}
	_pending_waits[target_player].append(wait_request)
	_events.append(shift_event.duplicate(true))
	_append_event_to_resolved_column(source_column_index, shift_event)
	return true


## 在两拍之间终止整条时间线。已经完成的列和原始提交保持不变；只有尚未开始的
## 玩家真实步骤会写入取消事件，BattleCore 生成的对齐/延后等待不会伪装成玩家损失。
func cancel_remaining(reason: String, affected_players: Array = []) -> Array[Dictionary]:
	if _column_open:
		push_error("BattleResolutionTimeline can only be truncated between columns")
		return []

	var cancelled: Array[Dictionary] = []
	for player: int in range(PLAYER_COUNT):
		var sequence: Array = _execution_sequences[player]
		for index: int in range(_cursors[player], sequence.size()):
			var step: Dictionary = sequence[index]
			if String(step.get("kind", "")) == STEP_WAIT:
				continue
			cancelled.append({
				"id": EVENT_SEQUENCE_STEP_CANCELLED,
				"column": _resolved_columns.size() - 1,
				"player": player,
				"step_id": String(step.get("step_id", "")),
				"kind": String(step.get("kind", "")),
				"item_id": String(step.get("item_id", "")),
				"slot": int(step.get("slot", -1)),
				"reason": reason,
			})
		_cursors[player] = sequence.size()
		_pending_waits[player].clear()
	_accepting_wait_requests = false

	if cancelled.is_empty():
		return []
	var source_column: int = _resolved_columns.size() - 1
	var truncated_event: Dictionary = {
		"id": EVENT_SEQUENCE_TRUNCATED,
		"event_id": _take_event_id(),
		"column": source_column,
		"reason": reason,
		"affected_players": affected_players.duplicate(),
		"cancelled_count": cancelled.size(),
	}
	if source_column >= 0:
		truncated_event["beat"] = source_column - _action_anchor_column
	_events.append(truncated_event.duplicate(true))
	if source_column >= 0:
		_append_event_to_resolved_column(source_column, truncated_event)
	for event: Dictionary in cancelled:
		event["event_id"] = _take_event_id()
		_events.append(event.duplicate(true))
		if source_column >= 0:
			_append_event_to_resolved_column(source_column, event)
	return cancelled.duplicate(true)


func to_result() -> Dictionary:
	return {
		"submitted_sequences": _submitted_sequences.duplicate(true),
		"resolved_columns": _resolved_columns.duplicate(true),
		"events": _events.duplicate(true),
		"action_anchor_column": _action_anchor_column,
	}


func _reset() -> void:
	_submitted_sequences = [[], []]
	_execution_sequences = [[], []]
	_cursors = [0, 0]
	_pending_waits = [[], []]
	_resolved_columns.clear()
	_events.clear()
	_current_column.clear()
	_column_open = false
	_accepting_wait_requests = false
	_next_event_id = 1
	_action_anchor_column = -1


func _copy_sequence(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


func _find_single_action_index(sequence: Array) -> int:
	var found: int = -1
	for index: int in range(sequence.size()):
		var step: Dictionary = sequence[index]
		if String(step.get("kind", "")) != STEP_ACTION:
			continue
		if found >= 0:
			return -1
		found = index
	return found


func _build_execution_sequences(action_indices: Array[int]) -> void:
	var max_pre: int = maxi(action_indices[0], action_indices[1])
	var post_counts: Array[int] = [
		_submitted_sequences[0].size() - action_indices[0] - 1,
		_submitted_sequences[1].size() - action_indices[1] - 1,
	]
	var max_post: int = maxi(post_counts[0], post_counts[1])
	var total_columns: int = max_pre + 1 + max_post
	_action_anchor_column = max_pre

	for player: int in range(PLAYER_COUNT):
		var execution: Array[Dictionary] = []
		var leading_waits: int = max_pre - action_indices[player]
		for column: int in range(leading_waits):
			execution.append(_make_alignment_wait_step(player, column))
		for value: Variant in _submitted_sequences[player]:
			execution.append((value as Dictionary).duplicate(true))
		while execution.size() < total_columns:
			execution.append(_make_alignment_wait_step(player, execution.size()))
		_execution_sequences[player] = execution


func _has_unresolved_execution_step(player: int) -> bool:
	var sequence: Array = _execution_sequences[player]
	return _cursors[player] < sequence.size()


func _has_unresolved_real_step(player: int) -> bool:
	var sequence: Array = _execution_sequences[player]
	for index: int in range(_cursors[player], sequence.size()):
		var step: Dictionary = sequence[index]
		if String(step.get("reason", "")) != WAIT_REASON_ACTION_ALIGNMENT:
			return true
	return false


func _is_player(player: int) -> bool:
	return player >= 0 and player < PLAYER_COUNT


func _take_event_id() -> int:
	var event_id: int = _next_event_id
	_next_event_id += 1
	return event_id


func _make_alignment_wait_step(player: int, column: int) -> Dictionary:
	return {
		"step_id": "server_alignment_wait_%d_%d" % [column, player],
		"kind": STEP_WAIT,
		"player": player,
		"reason": WAIT_REASON_ACTION_ALIGNMENT,
		"beat": column - _action_anchor_column,
	}


func _make_wait_step(player: int, column: int, request: Dictionary) -> Dictionary:
	var caused_by_event_id: int = int(request["caused_by_event_id"])
	return {
		"step_id": "server_wait_%d_%d_%d" % [column, player, caused_by_event_id],
		"kind": STEP_WAIT,
		"player": player,
		"reason": WAIT_REASON_SEQUENCE_SHIFT,
		"source_player": int(request["source_player"]),
		"cause_step_id": String(request["cause_step_id"]),
		"caused_by_event_id": caused_by_event_id,
	}


func _make_wait_executed_event(
		player: int,
		column: int,
		wait_step: Dictionary,
		request: Dictionary
) -> Dictionary:
	return {
		"id": EVENT_SEQUENCE_WAIT_EXECUTED,
		"event_id": _take_event_id(),
		"column": column,
		"source_player": int(request["source_player"]),
		"player": player,
		"step_id": String(wait_step["step_id"]),
		"cause_step_id": String(request["cause_step_id"]),
		"caused_by_event_id": int(request["caused_by_event_id"]),
	}


func _append_event_to_resolved_column(column_index: int, event: Dictionary) -> void:
	var column: Dictionary = _resolved_columns[column_index]
	var column_events: Array = column["events"]
	column_events.append(event.duplicate(true))
	column["events"] = column_events
	_resolved_columns[column_index] = column
