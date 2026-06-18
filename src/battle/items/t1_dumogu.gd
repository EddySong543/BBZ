extends ItemEffect

## 毒蘑菇：敌方出战中毒，下回合 −0.5 HP（自结算·不依赖命中·走 pending_damage 在下回合 Phase 0 落地）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.pending_damage[opp][target] += int(data.params.get("dot", 1))
