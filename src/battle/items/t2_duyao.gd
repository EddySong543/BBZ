extends ItemEffect

## 毒药瓶：为当时的敌方出战英雄叠加毒素。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	var layers: int = int(battle.get_status(opp, target, "poison", 0))
	battle.set_status(opp, target, "poison", layers + int(data.params.get("poison", 3)))
