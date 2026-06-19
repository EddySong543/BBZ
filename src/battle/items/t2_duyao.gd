extends ItemEffect

## 毒药瓶：敌方出战 +2 层毒（1.0 引爆值，任意攻击引爆 = 蛇毒 D2·喂蛇/虎双段）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.set_status(opp, target, "poison", int(battle.get_status(opp, target, "poison", 0)) + int(data.params.get("poison", 2)))
