extends ItemEffect

## 魔力水晶：本回合你不攻击，则 +0.5 能（静则凝魔；奖励守 / 过渡回合）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if not ActionDef.is_attack(battle.selected_action[player]):
		battle._gain_energy(player, int(data.params.get("energy", 1)))
