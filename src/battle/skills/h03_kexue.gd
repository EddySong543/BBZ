extends HeroSkill

## h03 寅虎【渴血】被动 · 团队层
## 寅虎击杀对手英雄后，全队"波"永久 +1.0（仅波、无上限叠加）；寅虎阵亡即清零。
## stacks 存寅虎自己的槽位；通过 modify_team_outgoing_damage 作用全队（寅虎可在替补席）。

func on_kill(_victim_player: int, _victim_slot: int, _overkill: int, battle: BattleCore, player: int, slot: int) -> void:
	# 本 hook 只在击杀者身上触发 → 此处即"寅虎击杀"。
	battle.set_status(player, slot, "xuexue", int(battle.get_status(player, slot, "xuexue", 0)) + 1)


func on_death(battle: BattleCore, player: int, slot: int) -> void:
	battle.set_status(player, slot, "xuexue", 0)


func modify_team_outgoing_damage(dmg: int, action: int, battle: BattleCore, _attacker_player: int, _attacker_slot: int, self_player: int, self_slot: int) -> int:
	if action == ActionDef.Action.ATTACK and battle.hp[self_player][self_slot] > 0:
		return dmg + int(battle.get_status(self_player, self_slot, "xuexue", 0)) * ActionDef.HP_UNIT
	return dmg
