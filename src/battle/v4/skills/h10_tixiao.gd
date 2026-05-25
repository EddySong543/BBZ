extends HeroSkillV4

## h10 酉鸡【啼晓】被动 · 单英雄
## 出战时，全局回合为 3 的倍数（第 3/6/9…回合）→ 本人"波"按大波伤害结算（2.0），能量仍按波（1）。
## 时机用 (turn_number + 1) % 3 == 0：turn_number 在 resolve 末才递增，故出伤时它是本回合 0-index。

func modify_outgoing_damage(dmg: int, action: int, battle: BattleEngineV4, _player: int, _slot: int) -> int:
	if action == ActionDefV4.Action.ATTACK and (battle.turn_number + 1) % 3 == 0:
		return ActionDefV4.get_base_damage(ActionDefV4.Action.BIG_ATTACK)   # 2.0
	return dmg
