extends ItemEffect

func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return target >= 0 and target < battle.hp[player].size() and battle.hp[player][target] > 0


func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	var total: int = 0
	for slot in range(battle.shield[player].size()):
		total += battle.shield[player][slot]
		battle.shield[player][slot] = 0
	battle.shield[player][target] = total
