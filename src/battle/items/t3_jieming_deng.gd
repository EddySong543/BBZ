extends ItemEffect


func resolves_on_submit() -> bool:
	return true


func queues_after_submit() -> bool:
	return true


func apply_on_submit(battle: BattleCore, player: int, _target: int, data: ItemData,
		events: Array) -> void:
	var gained: int = battle._gain_energy(player, battle.energy_max[player] - battle.energy[player])
	events.append({id = "jieming_energy", player = player, item_id = data.item_id,
		amount = gained})


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.lower_active_hp_to(player, int(data.params.get("hp", 2)), data.item_id)
