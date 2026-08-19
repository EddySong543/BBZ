extends ItemEffect


func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return battle.is_dead_reserve(player, target)


func prepare_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.revive_dead_reserve(player, target, int(data.params.get("hp", 2)), data.item_id)
