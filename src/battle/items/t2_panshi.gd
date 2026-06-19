extends ItemEffect

## 磐石卷轴：你这次「大防」少耗 1 能。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.BIG_DEFEND:
		battle.add_item_mod(player, "cost_save", int(data.params.get("save", 2)))
