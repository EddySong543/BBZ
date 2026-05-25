extends HeroSkillV4

## h02 丑牛【怒目】被动 · 单英雄
## HP < 满血时，本人波/大波 +1 伤（+1.0）。下场即失效（hook 仅出战英雄触发）。
## 数值：+1 伤 = +HP_UNIT 半点。

func modify_outgoing_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	if battle.hp[player][slot] < battle.max_hp[player][slot]:
		return dmg + ActionDefV4.HP_UNIT
	return dmg
