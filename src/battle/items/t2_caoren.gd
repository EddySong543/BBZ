extends ItemEffect

## 替身草人：你「切换」时下场者留个稻草替身，对手本回合对你的攻击落空（金蝉脱壳·自保）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.SWITCH:
		battle.set_item_mod(1 - player, "atk_nullify", true)
