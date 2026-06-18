extends ItemEffect

## 风之靴：本回合若你「切换」，下回合你的攻击 +0.5 伤（借风势而上·跨回合 buff）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.SWITCH:
		battle.item_buffs[player]["next_atk_bonus"] = int(data.params.get("bonus", 1))
