extends ItemEffect

## 妖火：敌方出战灼烧，下回合 −0.5 HP 且该回合无法回血（自结算 DoT + 封治疗）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.pending_damage[opp][target] += int(data.params.get("dot", 1))
	battle.set_status(opp, target, "noheal_turn", battle.turn_number + 1)
