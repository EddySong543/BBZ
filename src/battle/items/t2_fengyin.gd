extends ItemEffect

## 封印卷轴：预定敌方下回合的道具封印次数。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.schedule_item_seal(opp, int(data.params.get("seals", 1)))
