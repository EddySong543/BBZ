extends ItemEffect


func can_use(battle: BattleCore, player: int, _target: int, data: ItemData) -> bool:
	var slot: int = battle.active_index[player]
	var threshold: int = int(data.params.get("hp", 6))
	return battle.hp[player][slot] > 0 and battle.hp[player][slot] < threshold


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var slot: int = battle.active_index[player]
	var threshold: int = int(data.params.get("hp", 6))
	battle._heal(player, slot, maxi(0, threshold - battle.hp[player][slot]))
