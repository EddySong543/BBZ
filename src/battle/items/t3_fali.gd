extends ItemEffect


func resolves_on_submit() -> bool:
	return true


func apply_on_submit(battle: BattleCore, player: int, _target: int, data: ItemData,
		events: Array) -> void:
	var gained: int = battle._gain_energy(player, int(data.params.get("energy", 8)))
	events.append({id = "item_energy_gain", player = player, item_id = data.item_id,
		amount = gained})
