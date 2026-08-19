extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, _data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["active"] = true


func relic_pre(battle: BattleCore, player: int, data: ItemData, state: Dictionary,
		events: Array) -> void:
	if battle.alive_count(player) != 1:
		return
	var action: int = battle.selected_action[player]
	if battle.will_attack_this_turn(player):
		battle.add_item_mod(player, "turn_base_attack_total_bonus", int(data.params.get("atk", 2)))
		state["attack_armed_turn"] = battle.turn_number
	if action in ActionDef.DEFEND_ACTIONS:
		var slot: int = battle.active_index[player]
		if battle.hp[player][slot] > 0:
			var amount: int = int(data.params.get("armor", 2))
			battle.shield[player][slot] += amount
			events.append({id = "relic_trigger", player = player, item_id = data.item_id,
				amount = amount, kind = "defense"})


func relic_second_pre(battle: BattleCore, player: int, data: ItemData,
		_state: Dictionary, events: Array) -> void:
	if battle.alive_count(player) != 1 or battle.selected_action[player] not in ActionDef.DEFEND_ACTIONS:
		return
	var slot: int = battle.active_index[player]
	if battle.hp[player][slot] <= 0:
		return
	var amount: int = int(data.params.get("armor", 2))
	battle.shield[player][slot] += amount
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = amount, kind = "defense"})


func relic_on_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, state: Dictionary, events: Array) -> void:
	if int(state.get("attack_armed_turn", -1)) != battle.turn_number \
			or int(context.get("source_slot", -1)) < 0:
		return
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = int(data.params.get("atk", 2)), kind = "attack"})
