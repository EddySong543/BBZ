extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["charges"] = int(state.get("charges", 0)) + int(data.params.get("charges", 1))


func relic_poison_detonate_bonus(_battle: BattleCore, player: int, layers: int,
		data: ItemData, state: Dictionary, events: Array) -> int:
	var charges: int = int(state.get("charges", 0))
	if charges <= 0 or layers <= 0:
		return 0
	var amount: int = layers * int(data.params.get("bonus_per_layer", 2))
	state["charges"] = charges - 1
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		amount = amount, layers = layers, charges = charges - 1})
	return amount


func relic_end(_battle: BattleCore, _player: int, _data: ItemData, state: Dictionary,
		_events: Array) -> bool:
	return int(state.get("charges", 0)) > 0
