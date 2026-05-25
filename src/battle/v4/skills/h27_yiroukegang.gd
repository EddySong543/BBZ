extends HeroSkillV4

## h27 节制【以柔克刚】被动 · 单英雄
## 受到 >1.0 伤时本回合只承受 1.0，溢出（伤害-1.0）延迟到下回合结算。
## Q4 裁定：a) 下回合全额落（不再平滑）；b) 切到替补仍落地（pending 挂 slot，引擎在回合开始结算）。

func modify_incoming_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int, _attacker_player: int) -> int:
	if dmg > ActionDefV4.HP_UNIT:
		battle.pending_damage[player][slot] += dmg - ActionDefV4.HP_UNIT
		return ActionDefV4.HP_UNIT
	return dmg
