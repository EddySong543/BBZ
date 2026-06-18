extends ItemEffect

## 后手：若对手本回合攻击 → 你 +1.0 甲；否则无效（料定对手出招才严防）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	if ActionDef.is_attack(battle.selected_action[1 - player]):
		battle.shield[player][target] += int(data.params.get("armor", 2))
