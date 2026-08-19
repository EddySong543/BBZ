extends ItemEffect

## 替身草人：本回合实际切换后，使敌方本回合整次基础攻击落空。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.arm_caoren(player)
