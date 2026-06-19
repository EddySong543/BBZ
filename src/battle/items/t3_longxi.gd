extends ItemEffect

## 龙息：本回合「大波」翻倍（4.0 穿防）；若对手「大防」会挡下 → 下回合力竭（强制 CHARGE）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.selected_action[player] != ActionDef.Action.BIG_ATTACK:
		return
	battle.set_item_mod(player, "atk_mult", 2)
	if battle.selected_action[1 - player] == ActionDef.Action.BIG_DEFEND:
		battle.item_buffs[player]["exhausted_next"] = true
