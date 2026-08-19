extends ItemEffect

## 定身符：当前回合及下回合的所有非死亡补位切换均无效。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.lock_switch_until(opp, battle.turn_number + 1)
