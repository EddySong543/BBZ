extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.ATTACK:
		battle.add_base_attack_aftereffect(player, data)


func apply_second_pre(battle: BattleCore, player: int, _target: int, data: ItemData,
		_events: Array) -> void:
	apply_pre(battle, player, -1, data)


func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, events: Array) -> void:
	if int(context.get("original_action", -1)) != ActionDef.Action.ATTACK \
			or not bool(context.get("connected", false)):
		return
	battle.item_buffs[player]["free_big_attack_until_turn"] = battle.turn_number + 1
	events.append({id = "free_big_attack_armed", player = player, item_id = data.item_id,
		until_turn = battle.turn_number + 1})
