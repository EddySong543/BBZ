extends HeroSkill

## h21 力量【降龙伏虎】被动 · 单英雄
## 受到单次 ≥2.0 伤的攻击 -1.0（大波 2.0→1.0、孤注/天威/倾力等大伤 -1.0）；
## 普通 1.0 伤的波不受影响。仅减力量本人受伤。
## 数值：阈值 = 2×HP_UNIT 半点（2.0）；减免 = HP_UNIT 半点（1.0）。

func modify_incoming_damage(dmg: int, _action: int, _battle: BattleCore, _player: int, _slot: int, _attacker_player: int) -> int:
	if dmg >= 2 * ActionDef.HP_UNIT:
		return dmg - ActionDef.HP_UNIT
	return dmg
