extends HeroSkill

## h08 未羊【替罪】主动 0 能 · 单英雄（代价自身、收益团队池）
## 消耗自身 1.0 HP → 团队池 +2 能（HP > 1.0 才可用，避免自杀）。无每局上限。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "tizui"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0

func can_use_active(battle: BattleCore, player: int, slot: int) -> bool:
	return battle.hp[player][slot] > ActionDef.HP_UNIT   # > 1.0 HP

func execute_active(battle: BattleCore, player: int, slot: int) -> void:
	battle.hp[player][slot] -= ActionDef.HP_UNIT
	battle.energy[player] = mini(battle.energy[player] + 2, ActionDef.MAX_ENERGY)
