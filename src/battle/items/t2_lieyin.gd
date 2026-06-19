extends ItemEffect

## 猎物印记：敌方出战本回合下次受击 +0.5（易伤·泛连携）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.set_status(opp, target, "marked", int(battle.get_status(opp, target, "marked", 0)) + int(data.params.get("amount", 1)))
