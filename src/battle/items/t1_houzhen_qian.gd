extends ItemEffect


func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return battle.is_living_reserve(player, target)


func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	battle.queue_end_turn_entry(player, target)
