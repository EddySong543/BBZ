extends HeroSkillV4

## h09 申猴【凶兽】被动 · 单英雄
## 连续出"波"伤害递增 1.0→2.0→3.0（封顶）；出非波动作 / 切换下场则连段归零；
## 被防/大防挡的波【仍计】连段（连段只看是否出波，不看是否命中）。
## 连段计数存 statuses["combo"]，随英雄保留。仅"波"(ATTACK)累进，大波/其他归零。

const MAX_COMBO := 3


func modify_outgoing_damage(dmg: int, action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	if action == ActionDefV4.Action.ATTACK:
		var combo: int = int(battle.get_status(player, slot, "combo", 0))
		return mini(combo + 1, MAX_COMBO) * ActionDefV4.HP_UNIT
	return dmg


func on_resolve_end(battle: BattleEngineV4, player: int, slot: int) -> void:
	# selected_action 此时尚未被 cleanup 重置 → 反映本回合动作。
	if battle.selected_action[player] == ActionDefV4.Action.ATTACK:
		var combo: int = int(battle.get_status(player, slot, "combo", 0))
		battle.set_status(player, slot, "combo", mini(combo + 1, MAX_COMBO))
	else:
		battle.set_status(player, slot, "combo", 0)


func on_switch_out(battle: BattleEngineV4, player: int, slot: int) -> void:
	battle.set_status(player, slot, "combo", 0)
