extends ItemEffect

## 锦囊：拆开随机获得 [+0.5 伤这击 / +0.5 甲 / +0.5 能] 之一（赌自己·凑不齐时的保底）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var roll: int = battle.rng.randi() % 3
	if roll == 0:
		battle.add_item_mod(player, "atk_bonus", 1)
	elif roll == 1:
		battle.shield[player][battle.active_index[player]] += 1
	else:
		battle._gain_energy(player, 1)
