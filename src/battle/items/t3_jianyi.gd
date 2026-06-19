extends ItemEffect

## 至臻剑意：你这次「大波」改为穿大防一次（砸穿一切防御·gate 在大波 6 半能慢蓄）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.BIG_ATTACK:
		battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_BIGDEF)
