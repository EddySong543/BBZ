extends HeroSkill

## h10 酉鸡【啼晓】被动 · 单英雄
## 出战时，全局回合为 3 的倍数（第 3/6/9…回合）→ 本人"波"完全等同大波：
##   伤害 2.0（modify_outgoing）+ 判定按大波（override_attack_kind：穿"防"、被"大防"挡）；能量仍按波（1）。
## 时机用 (turn_number + 1) % 3 == 0：turn_number 在 resolve 末才递增，故出伤时它是本回合 0-index。

func modify_outgoing_damage(dmg: int, action: int, battle: BattleCore, _player: int, _slot: int) -> int:
	if action == ActionDef.Action.ATTACK and (battle.turn_number + 1) % 3 == 0:
		return ActionDef.get_base_damage(ActionDef.Action.BIG_ATTACK)   # 2.0
	return dmg


func override_attack_kind(action: int, battle: BattleCore, _player: int, _slot: int) -> int:
	if action == ActionDef.Action.ATTACK and (battle.turn_number + 1) % 3 == 0:
		return ActionDef.Action.BIG_ATTACK   # 判定升级为大波：穿"防"、被"大防"挡
	return action
