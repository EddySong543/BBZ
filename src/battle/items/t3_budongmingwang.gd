extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["charges"] = int(state.get("charges", 0)) + int(data.params.get("charges", 3))


func relic_on_defense_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, state: Dictionary, events: Array) -> void:
	var charges: int = int(state.get("charges", 0))
	var amount: int = int(context.get("raw_damage_total", 0))
	if charges <= 0 or not bool(context.get("blocked", false)) \
			or bool(context.get("connected", false)) or amount <= 0:
		return
	var slot: int = battle.active_index[player]
	if battle.hp[player][slot] <= 0:
		return
	battle.shield[player][slot] += amount
	state["charges"] = charges - 1
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = amount, charges = charges - 1})


func relic_end(_battle: BattleCore, _player: int, _data: ItemData, state: Dictionary,
		_events: Array) -> bool:
	return int(state.get("charges", 0)) > 0
