extends HeroSkillV4

## h05 辰龙【天威】被动 · 单英雄
## HP = 满血时，本人大波 +2 伤（2.0 → 4.0）。受任何伤即失效（HP<满血则条件不成立）。
## 数值：+2 伤 = +2×HP_UNIT 半点。仅大波，波不加。

func modify_outgoing_damage(dmg: int, action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	if action == ActionDefV4.Action.BIG_ATTACK and battle.hp[player][slot] == battle.max_hp[player][slot]:
		return dmg + 2 * ActionDefV4.HP_UNIT
	return dmg
