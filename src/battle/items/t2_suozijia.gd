extends ItemEffect

## 锁子连环甲：你「大防」后，下回合 +0.5 甲（余韵·跨回合 buff）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.BIG_DEFEND:
		battle.item_buffs[player]["next_armor"] = int(data.params.get("armor", 1))
