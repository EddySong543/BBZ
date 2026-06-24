extends ItemEffect

## 天罗地网〔一次性〕：封住对手全部道具槽（封 3 次用道具）+ 本回合禁止切换（锁死其整套计划）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.item_buffs[opp]["item_lock"] = int(battle.item_buffs[opp].get("item_lock", 0)) + 3
	battle.set_item_mod(opp, "no_switch", 1)
