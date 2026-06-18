extends ItemEffect

## 解毒药水：回 0.5 HP，并解除自身全部毒 / 灼（先净化再回血，使被妖火封血者也能回）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.statuses[player][target].erase("poison")
	battle.statuses[player][target].erase("burn")
	battle.statuses[player][target].erase("noheal_turn")
	battle.pending_damage[player][target] = 0
	battle._heal(player, target, int(data.params.get("heal", 1)))
