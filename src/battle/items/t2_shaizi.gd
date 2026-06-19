extends ItemEffect

## 命运的骰子：随机 +1.0 伤 / 甲 / 能 之一（赌自己；"可重抛"留待 UI）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var n: int = int(data.params.get("amount", 2))
	match battle.rng.randi() % 3:
		0:
			battle.add_item_mod(player, "atk_bonus", n)
		1:
			battle.shield[player][target] += n
		_:
			battle._gain_energy(player, n)
