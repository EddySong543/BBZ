extends ItemEffect

## 封印卷轴：封住对手 1 个道具槽（其下次用道具被封 1 次，随后自解）。
## 实现：给对手挂 item_lock 计数；引擎在对手 use_item 时消耗一次、拒绝一次。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.item_buffs[opp]["item_lock"] = int(battle.item_buffs[opp].get("item_lock", 0)) + 1
