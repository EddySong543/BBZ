extends ItemEffect

## 臭鸡蛋：敌方本回合基础攻击的总伤害 -1（最低为 0）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if not battle.will_attack_this_turn(opp):
		return
	if battle.item_debuff_blocked(opp):
		return
	battle.add_item_mod(opp, "base_attack_total_penalty", int(data.params.get("penalty", 2)))
