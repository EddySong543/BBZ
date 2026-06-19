extends ItemEffect

## 力量的代价：对手本回合费能动作（大波/大防）多耗 1 能（课税·配碎能卡死）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	var oa: int = battle.selected_action[opp]
	if oa == ActionDef.Action.BIG_ATTACK or oa == ActionDef.Action.BIG_DEFEND:
		battle.add_item_mod(opp, "cost_add", int(data.params.get("tax", 2)))
