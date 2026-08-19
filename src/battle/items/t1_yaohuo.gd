extends ItemEffect

## 妖火：记录目标；下一回合结束时若该英雄仍在场，失去 1.5 生命。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.add_timed_item_effect(opp, {
		id = "yaohuo",
		target_slot = target,
		due_turn = battle.turn_number + 1,
		amount = int(data.params.get("loss", 3)),
		source_player = player,
	})
