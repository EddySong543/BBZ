extends ItemEffect

## 算命先生的铜钱：若对手本回合攻击 → +0.5 甲，否则 → +0.5 能（自适应对冲）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	if ActionDef.is_attack(battle.selected_action[1 - player]):
		battle.shield[player][target] += int(data.params.get("armor", 1))
	else:
		battle._gain_energy(player, int(data.params.get("energy", 1)))
