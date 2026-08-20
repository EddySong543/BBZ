extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var cleared: int = battle.clear_pending_hit_skill_effects()
	battle.queue_item_events(player, [{id = "hit_skill_effects_cleared", player = player,
		count = cleared}])
