extends ItemEffect

## 算命铜钱：若对手本回合攻击 → +1 护盾，否则 → +1 能量（自适应对冲）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	if battle.will_attack_this_turn(1 - player):
		battle.shield[player][target] += int(data.params.get("armor", 1))
	else:
		battle._gain_energy(player, int(data.params.get("energy", 1)))
