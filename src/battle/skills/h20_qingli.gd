extends HeroSkill

## h20 战车【倾力一击】主动 · 单英雄
## 耗光全部能量，造成"每 1 能 = 1.0"的一击（穿"防"、被"大防"挡）。需 ≥1 能可用。
## 例：5 能 → 5.0 伤。Step5b 旗标=是否加伤害 cap 待 playtest。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "qingli"

func active_cost(battle: BattleCore, player: int, _slot: int) -> int:
	return battle.energy[player]   # 全部能量

func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.energy[player] >= 1

func active_is_attack() -> bool:
	return true

func active_attack_kind() -> int:
	return ActionDef.Action.BIG_ATTACK   # 穿"防"、被"大防"挡

func active_attack_damage(battle: BattleCore, player: int, _slot: int) -> int:
	# 用回合开始时的能量快照（Phase 2 已扣光当前 energy）
	return battle._energy_before[player] * ActionDef.HP_UNIT
