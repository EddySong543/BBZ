extends ItemEffect

## 破盾咒：若对手本回合用「防」，你这次攻击穿防（盲选赌对手会龟）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.selected_action[1 - player] == ActionDef.Action.DEFEND:
		battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_DEF)
