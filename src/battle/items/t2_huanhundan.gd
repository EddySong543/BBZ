extends ItemEffect

## 还魂丹：本局一次，你出战将死时改为保留 0.5 HP（持久标记，触发即消）。
func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	battle.set_status(player, target, "huanhun_ready", 1)
