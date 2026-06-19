extends ItemEffect

## 破魔失：你这次「波」改为穿防。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.ATTACK:
		battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_DEF)
