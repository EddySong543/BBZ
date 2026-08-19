extends ItemEffect


func relic_on_activate(battle: BattleCore, player: int, data: ItemData,
		state: Dictionary, events: Array) -> void:
	var turns: int = int(data.params.get("turns", 3))
	state["remaining_turns"] = int(state.get("remaining_turns", 0)) + maxi(0, turns - 1)
	state["activated_turn"] = battle.turn_number
	var gained: int = battle._gain_energy(player, int(data.params.get("energy", 3)))
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = gained, remaining_turns = int(state["remaining_turns"])})


func relic_end(battle: BattleCore, player: int, data: ItemData, state: Dictionary,
		events: Array) -> bool:
	var remaining: int = int(state.get("remaining_turns", 0))
	if remaining <= 0:
		return false
	if int(state.get("activated_turn", -1)) == battle.turn_number:
		return true
	var gained: int = battle._gain_energy(player, int(data.params.get("energy", 3)))
	remaining -= 1
	state["remaining_turns"] = remaining
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = gained, remaining_turns = remaining})
	return remaining > 0
