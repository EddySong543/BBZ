extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["remaining_turns"] = int(state.get("remaining_turns", 0)) \
		+ int(data.params.get("turns", 3))


func relic_end(battle: BattleCore, player: int, data: ItemData, state: Dictionary,
		events: Array) -> bool:
	var remaining: int = int(state.get("remaining_turns", 0))
	if remaining <= 0:
		return false
	var slot: int = battle.active_index[player]
	var healed: int = battle._heal(player, slot, int(data.params.get("heal", 3)))
	remaining -= 1
	state["remaining_turns"] = remaining
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = healed, remaining_turns = remaining})
	return remaining > 0
