extends ItemEffect

## 打神鞭：强制对手本回合切换出战英雄（指向其首个存活替补；喂戌狗穷追·偏 PvE）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	var reserves: Array[int] = battle.living_reserves(opp)
	if reserves.size() > 0:
		battle.set_item_mod(opp, "forced_switch", reserves[0])
