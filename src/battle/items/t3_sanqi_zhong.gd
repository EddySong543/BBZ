extends ItemEffect


func prepare_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var ended: int = battle.end_all_active_item_effects()
	battle.queue_item_events(player, [{id = "sanqi_ended", player = player,
		item_id = data.item_id, count = ended}])
