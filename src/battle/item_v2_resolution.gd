class_name ItemV2Resolution
extends RefCounted

## 冻结20件道具的单机权威序列结算器。
## 双方提交序列以唯一公共行动为0拍对齐；每列先从同一开列快照建立节点结果，再统一落账。
## 因此同列双方都能完成已经开始的节点，同列新效果只影响之后的列。

const RULES := preload("res://src/battle/item_v2_rules.gd")
const TIMELINE := preload("res://src/battle/battle_resolution_timeline.gd")


static func resolve(battle) -> Dictionary:
	var events: Array = []
	_ensure_sequences(battle)
	for player: int in [0, 1]:
		if battle.can_item_v2_draw(player):
			battle.pass_item_v2_draw(player)

	battle._pending_reserve_pursuit_source.assign([-1, -1])
	battle._pending_reserve_pursuit_target.assign([-1, -1])
	battle._active_transform_requested.assign([false, false])
	battle._retain_big_defend_candidate.assign([false, false])
	battle._retained_big_defend_in_use.assign([false, false])
	battle._imod = [{}, {}]
	for player: int in [0, 1]:
		battle.item_buffs[player]["actual_switches_this_turn"] = []

	var silenced_swaps: Array = _apply_skill_silence(battle)
	_resolve_due_damage(battle, events)

	# free_switch() 在选择期只做了逻辑预览。结算先回到首个真实起点，再在提交节点
	# 到达时执行 hook；这样道具放在免费切换前后会得到不同、可验证的结果。
	var free_switch_intents: Array = battle._pending_free_switches.duplicate(true)
	var free_switch_cursors: Array[int] = [0, 0]
	for player: int in [0, 1]:
		if not free_switch_intents[player].is_empty():
			battle.active_index[player] = int((free_switch_intents[player][0] as Dictionary).get(
				"from", battle.active_index[player]))
	battle._pending_free_switches = [[], []]

	var timeline = TIMELINE.new()
	timeline.setup(battle.item_v2_command_sequences)
	var standing_defenses: Array[int] = [-1, -1]
	var submitted_actions: Array[int] = [-1, -1]
	var action_executed: Array[bool] = [false, false]
	var action_step_ids: Array[String] = ["", ""]
	var action_contexts_by_column: Array = []

	while timeline.has_next_column():
		var column: Dictionary = timeline.begin_next_column()
		if column.is_empty():
			break
		var column_index: int = int(column.get("column", -1))
		var steps: Array = column.get("steps", [null, null])
		var opening_snapshot = battle.clone()
		var item_operations: Array = []
		var action_steps: Array = [null, null]
		var switch_steps: Array = [null, null]

		for player: int in [0, 1]:
			var value: Variant = steps[player] if player < steps.size() else null
			if not value is Dictionary:
				continue
			var step: Dictionary = value
			match String(step.get("kind", "")):
				"item":
					var operation: Dictionary = _prepare_item_step(
						battle, opening_snapshot, player, step, events, column_index)
					if not operation.is_empty():
						item_operations.append(operation)
				"action":
					action_steps[player] = step
				"free_switch":
					switch_steps[player] = step

		var contexts: Array = _resolve_action_column(
			battle, action_steps, standing_defenses, submitted_actions,
			action_executed, action_step_ids, events, column_index)
		RULES.apply_column_operations(battle, item_operations, events, column_index)
		_apply_free_switch_column(battle, switch_steps, free_switch_intents,
			free_switch_cursors, events, column_index)
		action_contexts_by_column.append(contexts.duplicate(true))
		timeline.complete_current_column()
		_request_sequence_shifts(battle, timeline, contexts, action_steps, events)

	var timeline_result: Dictionary = timeline.to_result()
	for event_variant: Variant in timeline_result.get("events", []):
		events.append((event_variant as Dictionary).duplicate(true))

	_finish_turn(battle, submitted_actions, silenced_swaps, events)
	var result := {
		"p1_hp": battle.current_hp(0),
		"p2_hp": battle.current_hp(1),
		"p1_energy": battle.energy[0],
		"p2_energy": battle.energy[1],
		"p1_action": submitted_actions[0],
		"p2_action": submitted_actions[1],
		"action_step_ids": action_step_ids.duplicate(),
		"events": events,
		"game_over": battle.game_over,
		"winner": battle.winner,
		"turn": battle.turn_number,
		"command_sequences": timeline_result.get("submitted_sequences", []).duplicate(true),
		"resolved_columns": timeline_result.get("resolved_columns", []).duplicate(true),
		"action_anchor_column": int(timeline_result.get("action_anchor_column", -1)),
		"sequence_events": timeline_result.get("events", []).duplicate(true),
		"action_contexts_by_column": action_contexts_by_column,
		"item_v2_public_history": battle.item_v2_public_history.duplicate(true),
	}
	_reset_after_turn(battle)
	return result


static func _ensure_sequences(battle) -> void:
	for player: int in [0, 1]:
		if not battle.item_v2_command_sequences[player].is_empty():
			continue
		battle.submit_item_v2_command_sequence(player, [{
			"kind": "action",
			"action": ActionDef.Action.CHARGE,
			"target": -1,
		}])


static func _prepare_item_step(battle, opening_snapshot, player: int,
		step: Dictionary, events: Array, column: int) -> Dictionary:
	var slot_index: int = int(step.get("slot", -1))
	if slot_index < 0 or slot_index >= battle.slots[player].size() \
			or not battle.slot_ready(player, slot_index):
		events.append({"id": "item_v2_step_rejected", "player": player,
			"slot": slot_index, "column": column, "reason": "slot_not_ready"})
		return {}
	var slot: Dictionary = battle.slots[player][slot_index]
	var data: ItemData = slot.get("item", null)
	if data == null or not data.is_prototype_v2() \
			or int(step.get("instance_uid", -1)) != int(slot.get("instance_uid", -2)) \
			or String(step.get("item_id", "")) != data.item_id:
		events.append({"id": "item_v2_step_rejected", "player": player,
			"slot": slot_index, "column": column, "reason": "instance_mismatch"})
		return {}
	var target: int = int(step.get("target", -1))
	var cost_units: int = RULES.item_cost_units(battle, player, data, false)
	var cost: int = cost_units * ActionDef.ENERGY_UNIT
	if battle.usable_energy(player) < cost:
		events.append({"id": "item_v2_step_rejected", "player": player,
			"slot": slot_index, "column": column, "reason": "energy"})
		return {}
	RULES.item_cost_units(battle, player, data, true)
	battle.energy[player] -= cost
	slot["current_durability"] = maxi(0,
		int(slot.get("current_durability", data.max_durability)) - 1)
	slot["used_turn"] = battle.turn_number
	if int(slot["current_durability"]) <= 0:
		slot["state"] = battle.SlotState.DEPLETED_PENDING
	battle.used_item_history[player].append({
		"item_id": data.item_id,
		"tier": data.tier,
		"instance_uid": int(slot.get("instance_uid", -1)),
		"turn": battle.turn_number,
	})
	var use_event := {
		"id": "item_v2_used",
		"player": player,
		"item_id": data.item_id,
		"item_name": data.item_name,
		"instance_uid": int(slot.get("instance_uid", -1)),
		"slot": slot_index,
		"target": target,
		"cost": cost,
		"durability": int(slot["current_durability"]),
		"column": column,
		"step_id": String(step.get("step_id", "")),
	}
	events.append(use_event)
	battle.item_v2_public_history.append(use_event.duplicate(true))
	return RULES.execution_operation(opening_snapshot, player, data, target)


static func _resolve_action_column(battle, steps: Array, standing_defenses: Array[int],
		submitted_actions: Array[int], action_executed: Array[bool],
		action_step_ids: Array[String], events: Array, column: int) -> Array:
	var actions: Array[int] = [-1, -1]
	var effective_actions: Array[int] = [-1, -1]
	var source_slots: Array[int] = [-1, -1]
	var contexts: Array = [_empty_attack_context(), _empty_attack_context()]
	var preemptive_actives_resolved: Array[bool] = [false, false]

	# 两边先独立完成合法提交，再统一扣费，避免玩家编号改变同列能否启动。
	for player: int in [0, 1]:
		var value: Variant = steps[player] if player < steps.size() else null
		if not value is Dictionary:
			continue
		var step: Dictionary = value
		action_step_ids[player] = String(step.get("step_id", ""))
		if action_executed[player]:
			events.append({"id": "item_v2_action_rejected", "player": player,
				"column": column, "reason": "duplicate_action"})
			continue
		if int(battle.item_buffs[player].get("item_v2_action_cancelled_turn", -1)) \
				== battle.turn_number or battle.hp[player][battle.active_index[player]] <= 0:
			events.append({"id": "item_v2_action_cancelled", "player": player,
				"column": column, "step_id": action_step_ids[player]})
			action_executed[player] = true
			continue
		if not battle.apply_choice(player, step):
			events.append({"id": "item_v2_action_rejected", "player": player,
				"column": column, "reason": "runtime_legality"})
			continue
		actions[player] = int(step.get("action", -1))
		effective_actions[player] = actions[player]
		submitted_actions[player] = actions[player]
		source_slots[player] = battle.active_index[player]
		action_executed[player] = true

	for player: int in [0, 1]:
		var action: int = actions[player]
		if action < 0:
			continue
		var cost: int = battle.action_cost(player, action)
		if battle._empowered_wave[player]:
			cost += battle.EMPOWERED_WAVE_COST
		if battle._energy_cap_discount[player] and cost > 0:
			var reduced: int = battle.reduce_energy_max(
				player, battle.ENERGY_CAP_DISCOUNT_COST,
				battle.ENERGY_CAP_DISCOUNT_FLOOR)
			if reduced == battle.ENERGY_CAP_DISCOUNT_COST:
				cost = maxi(0, cost - battle.ENERGY_CAP_DISCOUNT_AMOUNT)
				events.append({"id": "h24_energy_cap_discount", "player": player,
					"amount": reduced, "saved": battle.ENERGY_CAP_DISCOUNT_AMOUNT,
					"new_max": battle.energy_max[player], "column": column})
		battle._pay_action_cost(player, cost, events)
		events.append({"id": "item_v2_action_started", "player": player,
			"action": action, "cost": cost, "column": column,
			"step_id": action_step_ids[player]})
		if action == ActionDef.ACTIVE:
			battle.set_status(player, source_slots[player], "active_uses",
				int(battle.get_status(player, source_slots[player], "active_uses", 0)) + 1)
			events.append({"id": "active_used", "player": player,
				"slot": source_slots[player], "column": column})

	# 共享0拍的窄例外：惊蛰先替换敌方出战英雄，并取消其已付费但尚未落账的基础行动。
	# 切换和其他主动技仍按普通同拍规则完整执行，不能被回滚。
	for player: int in [0, 1]:
		if actions[player] != ActionDef.ACTIVE:
			continue
		var source_slot: int = source_slots[player]
		var skill = battle._skills[player][source_slot]
		var victim: int = 1 - player
		if skill == null or not skill.active_preempts_enemy_basic_action() \
				or not _is_basic_action(actions[victim]) \
				or battle.hp[player][source_slot] <= 0:
			continue
		skill.execute_active(battle, player, source_slot)
		preemptive_actives_resolved[player] = true
		var pull: int = battle._forced_pull[victim]
		if pull >= 0 and battle.is_living_reserve(victim, pull):
			var replaced_slot: int = battle.active_index[victim]
			battle._perform_switch(victim, replaced_slot, pull, events, true)
			if battle.active_index[victim] == pull:
				actions[victim] = -1
				effective_actions[victim] = -1
				standing_defenses[victim] = -1
				battle._retain_big_defend_candidate[victim] = false
				events.append({"id": "h21_forced_pull", "player": victim,
					"source_player": player, "from": replaced_slot,
					"to": pull, "column": column})
				events.append({"id": "h21_action_cancelled", "player": victim,
					"source_player": player, "slot": replaced_slot,
					"action": submitted_actions[victim], "column": column,
					"step_id": action_step_ids[victim]})
				events.append({"id": "item_v2_action_cancelled", "player": victim,
					"source_player": player, "action": submitted_actions[victim],
					"column": column, "step_id": action_step_ids[victim]})
		battle._forced_pull[victim] = -1

	# 抢先打断完成后，未被取消的攒/防御才正式产生效果。
	for player: int in [0, 1]:
		var action: int = actions[player]
		if action == ActionDef.Action.CHARGE:
			var gained: int = battle._gain_energy(player,
				int(ActionDef.BASE_ACTION_DEF[action]["energy_gain"]))
			events.append({"id": "charge_gain", "player": player,
				"amount": gained, "column": column})
		elif action in ActionDef.DEFEND_ACTIONS:
			var effective: int = RULES.take_defense_action(battle, player, action)
			effective_actions[player] = effective
			standing_defenses[player] = effective
			if effective != action:
				events.append({"id": "item_v2_defend_upgraded", "player": player,
					"from": action, "to": effective, "column": column})
			if effective == ActionDef.Action.BIG_DEFEND:
				var skill = battle._skills[player][source_slots[player]]
				battle._retain_big_defend_candidate[player] = skill != null \
					and skill.retains_unused_big_defend()

	# 公共切换的既有语义仍是动作内部先换人，故同列攻击打到换上来的英雄。
	for player: int in [0, 1]:
		if actions[player] == ActionDef.Action.SWITCH:
			battle._perform_switch(player, source_slots[player],
				int((steps[player] as Dictionary).get("target", -1)), events, true)

	# 即时主动技沿用公共动作内部的既定子顺序：主动切换之后、攻击伤害之前。
	# 因此同拍被击败也不能吞掉已经启动的主动技；双方请求随后从共同快照落账。
	for player: int in [0, 1]:
		if actions[player] != ActionDef.ACTIVE:
			continue
		var source_slot: int = source_slots[player]
		var skill = battle._skills[player][source_slot]
		if skill != null and not skill.active_is_attack() \
				and not preemptive_actives_resolved[player]:
			skill.execute_active(battle, player, source_slot)
	_resolve_active_side_effects(battle, action_executed, events, column)

	var hitlists: Array = [[], []]
	for player: int in [0, 1]:
		var action: int = actions[player]
		if action < 0:
			continue
		var step: Dictionary = steps[player]
		var source_slot: int = source_slots[player]
		if ActionDef.is_attack(action):
			_build_base_attack_hits(battle, player, action, step, source_slot,
				hitlists[player], contexts[player], events, column)
		elif action == ActionDef.ACTIVE:
			var skill = battle._skills[player][source_slot]
			if skill != null and skill.active_is_attack():
				var kind: int = skill.active_attack_kind()
				var damage: int = maxi(battle._apply_team_outgoing(
					skill.active_attack_damage(battle, player, source_slot),
					kind, player, source_slot), 0)
				var penetration: int = skill.attack_penetration(
					ActionDef.base_penetration(kind), ActionDef.ACTIVE,
					battle, player, source_slot)
				if damage > 0:
					hitlists[player].append({"damage": damage, "kind": kind,
						"pen": penetration, "riders": [], "action": true,
						"active": true, "src_slot": source_slot})

	var defense_actions: Array[int] = standing_defenses.duplicate()
	for attacker: int in [0, 1]:
		for hit_variant: Variant in hitlists[attacker]:
			var was_connected: bool = bool(contexts[attacker].get("connected", false))
			battle._apply_resolve_hit(attacker, hit_variant as Dictionary,
				defense_actions, events, contexts[attacker])
			if not was_connected and bool(contexts[attacker].get("connected", false)):
				RULES.take_thorns_after_connected_hit(
					battle, 1 - attacker, attacker, events, column)
	battle._resolve_reserve_pursuits(events)

	return contexts


static func _is_basic_action(action: int) -> bool:
	return action in [
		ActionDef.Action.CHARGE,
		ActionDef.Action.ATTACK,
		ActionDef.Action.DEFEND,
		ActionDef.Action.BIG_ATTACK,
		ActionDef.Action.BIG_DEFEND,
	]


static func _build_base_attack_hits(battle, player: int, submitted_action: int,
		step: Dictionary, source_slot: int, hits: Array, context: Dictionary,
		events: Array, column: int) -> void:
	context["source_slot"] = source_slot
	context["original_action"] = submitted_action
	var split: bool = battle._split_big_wave[player] \
		and submitted_action == ActionDef.Action.BIG_ATTACK
	var wave_upgraded: bool = submitted_action == ActionDef.Action.ATTACK \
		and battle.upgrade_next_wave[player]
	var actual_action: int = ActionDef.Action.ATTACK if split else (
		ActionDef.Action.BIG_ATTACK if wave_upgraded else submitted_action)
	context["actual_action"] = actual_action
	var requested_target: int = int(step.get("target", -1))
	var modifiers: Dictionary = RULES.take_attack_modifiers(
		battle, player, actual_action, requested_target)
	var damage: int = maxi(battle._calc_outgoing(player, actual_action)
		+ int(modifiers.get("bonus", 0)) - int(modifiers.get("penalty", 0)), 0)
	if battle._empowered_wave[player] and submitted_action == ActionDef.Action.ATTACK:
		damage += battle.EMPOWERED_WAVE_DAMAGE
		events.append({"id": "longyuji_empowered", "player": player,
			"amount": battle.EMPOWERED_WAVE_DAMAGE, "column": column})
	var target: int = int(modifiers.get("target", -1))
	if target < 0 and requested_target >= 0:
		target = requested_target
	var skill = battle._skills[player][source_slot]
	var jianqi_spent: int = 0
	if battle._jianqi_attack[player] and skill != null \
			and skill.enables_jianqi_attack():
		jianqi_spent = int(battle.get_team_status(player, "jianqi", 0))
		if jianqi_spent >= 2:
			battle.set_team_status(player, "jianqi", 0)
			events.append({"id": "h10_jianqi_attack", "player": player,
				"amount": jianqi_spent, "action": submitted_action,
				"column": column})
		else:
			jianqi_spent = 0
	var kind: int = actual_action
	if skill != null and not split:
		kind = skill.override_attack_kind(actual_action, battle, player, source_slot)
	if wave_upgraded:
		kind = ActionDef.Action.BIG_ATTACK
	var penetration: int = ActionDef.base_penetration(kind)
	if skill != null:
		penetration = skill.attack_penetration(
			ActionDef.base_penetration(kind), actual_action,
			battle, player, source_slot)
	if wave_upgraded:
		penetration = maxi(penetration, ActionDef.Pen.PIERCE_DEF)
		battle.upgrade_next_wave[player] = false
	if jianqi_spent > 0 and skill != null:
		penetration = skill.jianqi_attack_penetration(penetration, jianqi_spent)
	var first_hit := {"damage": damage, "kind": kind, "pen": penetration,
		"riders": [], "action": true, "active": false,
		"src_slot": source_slot, "target_slot": target}
	hits.append(first_hit)
	if split:
		# 第二段是独立的普通「波」；不复制第一段消费掉的下一次攻击/波/指定目标状态。
		var second_damage: int = maxi(battle._calc_outgoing(
			player, ActionDef.Action.ATTACK), 0)
		var second_kind: int = ActionDef.Action.ATTACK
		var second_pen: int = ActionDef.base_penetration(second_kind)
		if skill != null:
			second_kind = skill.override_attack_kind(
				ActionDef.Action.ATTACK, battle, player, source_slot)
			second_pen = skill.attack_penetration(ActionDef.base_penetration(second_kind),
				ActionDef.Action.ATTACK, battle, player, source_slot)
		hits.append({"damage": second_damage, "kind": second_kind,
			"pen": second_pen, "riders": [], "action": true, "active": false,
			"src_slot": source_slot, "target_slot": -1})
		events.append({"id": "h13_split_big_wave", "player": player,
			"column": column})


static func _empty_attack_context() -> Dictionary:
	return {"executed": false, "source_slot": -1, "target_slot": -1,
		"connected": false, "original_action": -1, "actual_action": -1,
		"raw_damage_total": 0, "damage_total": 0, "hp_damage_total": 0,
		"blocked": false, "blocked_by_big_defend": false,
		"target_defeated": false, "hit_effect_triggers": 1}


static func _apply_free_switch_column(battle, steps: Array, intents: Array,
		cursors: Array[int], events: Array, column: int) -> void:
	for player: int in [0, 1]:
		var value: Variant = steps[player] if player < steps.size() else null
		if not value is Dictionary:
			continue
		var cursor: int = cursors[player]
		if cursor < 0 or cursor >= intents[player].size():
			events.append({"id": "free_switch_cancelled", "player": player,
				"column": column, "reason": "missing_intent"})
			continue
		var intent: Dictionary = intents[player][cursor]
		var target: int = int((value as Dictionary).get("target", -1))
		if target != int(intent.get("to", -2)):
			events.append({"id": "free_switch_cancelled", "player": player,
				"column": column, "reason": "target_mismatch"})
			continue
		battle._perform_switch(player, int(intent.get("from", battle.active_index[player])),
			target, events, true)
		cursors[player] += 1


static func _request_sequence_shifts(battle, timeline, contexts: Array,
		steps: Array, events: Array) -> void:
	for player: int in [0, 1]:
		var value: Variant = steps[player] if player < steps.size() else null
		if not value is Dictionary or String((value as Dictionary).get("kind", "")) != "action":
			continue
		var context: Dictionary = contexts[player]
		if not bool(context.get("connected", false)):
			continue
		var source_slot: int = int(context.get("source_slot", -1))
		if source_slot < 0 or source_slot >= battle._skills[player].size():
			continue
		var skill = battle._skills[player][source_slot]
		if skill == null or not skill.shifts_enemy_sequence_after_base_attack(
				battle, player, source_slot, context):
			continue
		var step_id: String = String((value as Dictionary).get("step_id", ""))
		if timeline.request_wait(player, 1 - player, step_id):
			events.append({"id": "item_v2_sequence_shift_requested",
				"source_player": player, "player": 1 - player,
				"cause_step_id": step_id})


static func _resolve_active_side_effects(battle, action_executed: Array[bool],
		events: Array, column: int) -> void:
	# h17：双方本拍的转变先从同一份目标快照落地。这样它既读取已完成的主动切换，
	# 又能在攻击伤害前完成；若同拍遇到惊蛰，也先完成主动技再被替换。
	var snapshots: Array = [null, null]
	for player: int in [0, 1]:
		if battle._active_transform_requested[player]:
			var enemy: int = 1 - player
			var target_slot: int = battle.active_index[enemy]
			if battle.hp[enemy][target_slot] > 0:
				snapshots[player] = battle._snapshot_hero_runtime(enemy, target_slot)
	for player: int in [0, 1]:
		if snapshots[player] == null:
			continue
		var slot: int = battle.active_index[player]
		var from_id: String = battle.heroes[player][slot].hero_id
		battle._apply_hero_runtime_snapshot(player, slot, snapshots[player])
		events.append({"id": "h17_transform", "player": player,
			"slot": slot, "from_hero_id": from_id,
			"to_hero_id": battle.heroes[player][slot].hero_id,
			"column": column})
	battle._active_transform_requested.assign([false, false])

	# 非抢先惊蛰随后完成强制替换。对手的切换或主动技已经完成，不能被回滚；
	# 对五种基础行动的打断则已在更早的0拍抢先分支处理并清空请求。
	for victim: int in [0, 1]:
		var pull: int = battle._forced_pull[victim]
		if pull < 0:
			continue
		if battle.is_living_reserve(victim, pull):
			var from_slot: int = battle.active_index[victim]
			battle._perform_switch(victim, from_slot, pull, events, true)
			if not action_executed[victim]:
				battle.item_buffs[victim]["item_v2_action_cancelled_turn"] = battle.turn_number
			events.append({"id": "h21_forced_pull", "player": victim,
				"source_player": 1 - victim, "from": from_slot,
				"to": pull, "column": column})
		battle._forced_pull[victim] = -1


static func _apply_skill_silence(battle) -> Array:
	var swaps: Array = []
	for player: int in [0, 1]:
		for slot: int in range(battle._skills[player].size()):
			if int(battle.get_status(player, slot, "silenced", 0)) > 0 \
					and battle._skills[player][slot] != null:
				swaps.append([player, slot, battle._skills[player][slot]])
				battle._skills[player][slot] = null
	return swaps


static func _resolve_due_damage(battle, events: Array) -> void:
	for player: int in [0, 1]:
		for slot: int in range(battle.pending_damage[player].size()):
			var amount: int = int(battle.pending_damage[player][slot])
			battle.pending_damage[player][slot] = 0
			if amount <= 0 or battle.hp[player][slot] <= 0:
				continue
			if battle._consume_fatal_damage_immunity(player, slot, amount, events):
				continue
			battle.hp[player][slot] -= amount
			events.append({"id": "deferred_damage", "player": player,
				"slot": slot, "amount": amount})


static func _finish_turn(battle, submitted_actions: Array[int], silenced_swaps: Array,
		events: Array) -> void:
	battle._resolve_timed_item_effects(events)
	for player: int in [0, 1]:
		if battle._retain_big_defend_candidate[player]:
			battle.retained_big_defend[player] = true
			battle.retained_big_defend_until_turn[player] = battle.turn_number + 1
			events.append({"id": "buzhui_shenyan_retained", "player": player})
		elif battle.retained_big_defend[player] \
				and battle.retained_big_defend_until_turn[player] <= battle.turn_number:
			battle.retained_big_defend[player] = false
			battle.retained_big_defend_until_turn[player] = -1
			events.append({"id": "buzhui_shenyan_expired", "player": player})
	battle._resolve_deaths(submitted_actions, events)
	for player: int in [0, 1]:
		var slot: int = battle.active_index[player]
		if battle.hp[player][slot] > 0:
			var skill = battle._skills[player][slot]
			if skill != null:
				skill.on_resolve_end(battle, player, slot)
	battle._expire_h20_vulnerabilities(events)
	for player: int in [0, 1]:
		battle._gain_energy(player, ActionDef.PASSIVE_ENERGY_GAIN, false, true)
	if battle.energy_burn_turn == battle.turn_number:
		events.append({"id": "h22_energy_burn", "p1_amount": battle.energy[0],
			"p2_amount": battle.energy[1]})
		battle.energy.assign([0, 0])
		battle.energy_burn_turn = -1
	for swap_variant: Variant in silenced_swaps:
		var swap: Array = swap_variant
		battle._skills[int(swap[0])][int(swap[1])] = swap[2]
		battle.set_status(int(swap[0]), int(swap[1]), "silenced", maxi(0,
			int(battle.get_status(int(swap[0]), int(swap[1]), "silenced", 0)) - 1))
	for player: int in [0, 1]:
		battle.item_buffs[player].erase("item_v2_action_cancelled_turn")
		battle.item_buffs[player].erase("actual_switches_this_turn")
	battle._econ_after_resolve()
	battle._last_action.assign(submitted_actions)
	battle.turn_number += 1
	battle._apply_due_energy_debts(events)
	battle._econ_unlock()


static func _reset_after_turn(battle) -> void:
	battle.selected_action.assign([-1, -1])
	battle._switch_to.assign([-1, -1])
	battle._active_target.assign([-1, -1])
	battle._attack_target.assign([-1, -1])
	battle._second_action.assign([-1, -1])
	battle._second_attack_target.assign([-1, -1])
	battle._empowered_wave.assign([false, false])
	battle._split_big_wave.assign([false, false])
	battle._jianqi_attack.assign([false, false])
	battle._blood_payment.assign([false, false])
	battle._blood_payment_source.assign([-1, -1])
	battle._energy_cap_discount.assign([false, false])
	battle.item_uses = [[], []]
	battle.item_v2_command_sequences = [[], []]
	battle.item_v2_draw_candidate_uids = [[], []]
