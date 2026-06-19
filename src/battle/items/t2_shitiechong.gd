extends ItemEffect

## 噬铁虫：腐蚀对手护甲，降其防御一级（大防→防、防→无·broken_armor，消耗式）。
func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.set_status(opp, target, "broken_armor", int(battle.get_status(opp, target, "broken_armor", 0)) + 1)
