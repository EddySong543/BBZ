extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, _data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["active"] = true


func relic_after_economy(battle: BattleCore, player: int, data: ItemData,
		_state: Dictionary, events: Array) -> void:
	battle.refill_one_empty_slot_with_random_t1(player, data.item_id, events)
