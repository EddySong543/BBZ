extends ItemEffect

## 猎物印记：当时的敌方出战英雄获得3层持续脆弱，换下场时清除。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	var current: int = int(battle.get_status(opp, target, "vuln", 0))
	battle.set_status(opp, target, "vuln", current + int(data.params.get("vuln", 3)))
