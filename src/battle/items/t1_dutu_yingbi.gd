extends ItemEffect

## 赌徒的硬币：抛币——我方或敌方本回合下一次基础攻击总伤害 +2。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.rng.randf() < 0.5:
		battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 4)))
	else:
		var opp: int = 1 - player
		if not battle.item_debuff_blocked(opp):
			battle.add_item_mod(opp, "base_attack_total_bonus", int(data.params.get("bonus", 4)))
