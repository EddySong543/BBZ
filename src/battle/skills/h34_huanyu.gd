extends HeroSkill

## h34 世界【寰宇同寂】主动 2 能 · cap 2 · 单英雄（作用全场除己）
## 对除世界外全场所有角色（己方其余 2 队友 + 对手全 3 名，含双方替补）各 1.0 伤（穿透防御/护盾）；
## 世界本人免疫。会炸己方队友 → 引爆前须算血线。死亡由引擎死亡相位统一处理（AOE 不触发 on_kill）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "huanyu"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 2

func active_per_game_cap() -> int:
	return 2

func execute_active(battle: BattleCore, player: int, slot: int) -> void:
	for p in [0, 1]:
		for s in range(battle.hp[p].size()):
			if p == player and s == slot:
				continue   # 世界免疫
			if battle.hp[p][s] > 0:
				battle.hp[p][s] -= ActionDef.HP_UNIT   # 穿透直接扣
