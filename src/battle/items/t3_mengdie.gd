extends ItemEffect

## 梦蝶〔一次性〕：把你与对手当前的 HP / 能量 / 道具栏整体对调（风水轮流转·高方差豪赌）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	var t_hp: Array = battle.hp[player]
	battle.hp[player] = battle.hp[opp]
	battle.hp[opp] = t_hp
	var t_e: int = battle.energy[player]
	battle.energy[player] = battle.energy[opp]
	battle.energy[opp] = t_e
	var t_s: Array = battle.slots[player]
	battle.slots[player] = battle.slots[opp]
	battle.slots[opp] = t_s
