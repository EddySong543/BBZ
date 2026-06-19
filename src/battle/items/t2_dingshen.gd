extends ItemEffect

## 定身符：对手本回合无法「切换」（钉住核心、克马；其切换动作落空）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	battle.set_item_mod(opp, "no_switch", 1)
