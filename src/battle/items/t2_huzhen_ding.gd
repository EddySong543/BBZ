extends ItemEffect

func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return target >= 0 and target < battle.hp[player].size() \
		and target != battle.active_index[player] and battle.hp[player][target] > 0


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.shield[player][target] += int(data.params.get("armor", 4))
