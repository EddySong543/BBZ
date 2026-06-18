extends ItemEffect

## 分神的铃铛：对手本回合若「攒」，少回 0.5 能（吵得分心·碎能的温和版）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.selected_action[opp] != ActionDef.Action.CHARGE:
		return
	if battle.item_debuff_blocked(opp):
		return
	battle.add_item_mod(opp, "charge_penalty", int(data.params.get("penalty", 1)))
