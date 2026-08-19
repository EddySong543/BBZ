extends ItemEffect


func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return battle.is_living_reserve(player, target)


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle._heal(player, target, int(data.params.get("heal", 4)))
