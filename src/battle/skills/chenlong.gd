class_name HeroSkillChenlong
extends HeroSkill

## h05 辰龙 — 龙威被动
## 每比对手多 2 点能量，攻击伤害 +1（按能量差额 / 2 向下取整加）。
##
## 与原 BattleCore._calc_attack_raw 内 chenlong 分支语义完全一致 —
## 迁移后不应改变任何现有测试结果。

func on_attack_calc(raw_dmg: int, _action: int, _battle: BattleCore, player: int, energy_before: Array) -> int:
	var diff: int = energy_before[player] - energy_before[1 - player]
	if diff >= 2:
		return raw_dmg + diff / 2
	return raw_dmg
