extends ItemEffect


func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return battle.is_living_reserve(player, target)


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.swap_active_reserve_vitals(player, target, data.item_id)
