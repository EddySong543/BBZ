extends ItemEffect

## 省力咒：本回合你做费能动作（大波 / 大防），省 0.5 能。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var act: int = battle.selected_action[player]
	if act == ActionDef.Action.BIG_ATTACK or act == ActionDef.Action.BIG_DEFEND:
		battle.add_item_mod(player, "cost_save", int(data.params.get("save", 1)))
