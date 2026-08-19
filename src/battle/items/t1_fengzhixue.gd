extends ItemEffect

## 回马枪：本回合实际发生「切换」后，下回合第一次基础攻击总伤害 +1.5。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var bonus: int = int(data.params.get("bonus", 3))
	# h07 的免费切换在选择阶段即时发生，早于道具结算；此处补认已经发生的切换。
	if battle.free_switch_usage_turn[player] == battle.turn_number \
			and battle.free_switch_uses[player] > 0:
		battle.item_buffs[player]["next_atk_total_bonus"] = int(
			battle.item_buffs[player].get("next_atk_total_bonus", 0)) + bonus
		return
	# 付费切换、强制切换和追击登场稍后统一经过 BattleCore._perform_switch。
	battle.add_item_mod(player, "switch_next_atk_total_bonus", bonus)
