extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, _data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["active"] = true


func relic_pre(battle: BattleCore, player: int, data: ItemData, _state: Dictionary,
		_events: Array) -> void:
	if battle.will_attack_this_turn(player):
		battle.add_item_mod(player, "turn_base_attack_total_bonus", int(data.params.get("bonus", 2)))


func relic_on_attack_resolved(_battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, _state: Dictionary, events: Array) -> void:
	if int(context.get("source_slot", -1)) < 0:
		return
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = int(data.params.get("bonus", 2)), kind = "attack"})


func relic_end(battle: BattleCore, player: int, data: ItemData, _state: Dictionary,
		events: Array) -> bool:
	if battle.will_attack_this_turn(player):
		return true
	var slot: int = battle.active_index[player]
	var lost: int = battle.lose_life(player, slot, int(data.params.get("backlash", 6)),
		events, data.item_id)
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = lost, kind = "backlash"})
	return false
