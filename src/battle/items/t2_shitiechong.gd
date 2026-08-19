extends ItemEffect

## 噬铁虫：本回合将敌方「防」「大防」的防御等级降低。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.set_item_mod(opp, "defense_step_down", 1)
