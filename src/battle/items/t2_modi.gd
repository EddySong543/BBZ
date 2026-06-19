extends ItemEffect

## 魔笛：敌方下一次「防 / 大防」完全失效（defend_null，消耗一次）。
func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.set_status(opp, target, "defend_null", int(battle.get_status(opp, target, "defend_null", 0)) + 1)
