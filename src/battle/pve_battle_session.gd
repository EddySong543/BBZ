extends RefCounted

## PvE 与公共战斗核心之间的局前/局后状态适配。
## 该文件位于 battle 层，因为跨战 HP 是引擎会话状态，不应由 UI 直写。


static func copy_team(team: Array) -> Array[HeroData]:
	var result: Array[HeroData] = []
	for value: Variant in team:
		if not value is HeroData:
			push_error("PveBattleSession: team entry is not HeroData")
			continue
		var source: HeroData = value as HeroData
		if source.hero_id.strip_edges().is_empty():
			push_error("PveBattleSession: blank HeroData is not a valid PvE combatant")
			continue
		var copy: HeroData = source.duplicate(true) as HeroData
		result.append(copy)
	return result


static func apply_initial_hp(battle: BattleCore, player_hp: Array, opponent_hp: Array) -> void:
	if battle == null:
		push_error("PveBattleSession: battle is required")
		return
	_apply_side_hp(battle, 0, player_hp)
	_apply_side_hp(battle, 1, opponent_hp)


static func _apply_side_hp(battle: BattleCore, side: int, values: Array) -> void:
	if values.is_empty():
		return
	for slot: int in range(mini(battle.hp[side].size(), values.size())):
		var maximum: int = int(battle.max_hp[side][slot])
		battle.hp[side][slot] = clampi(int(values[slot]), 0, maximum)


static func capture_result(battle: BattleCore, outcome: String) -> Dictionary:
	var team_hp: Array[int] = []
	var opponent_hp: Array[int] = []
	if battle != null:
		for value: Variant in battle.hp[0]:
			team_hp.append(maxi(0, int(value)))
		for value: Variant in battle.hp[1]:
			opponent_hp.append(maxi(0, int(value)))
	return {
		"outcome": outcome,
		"beats": battle.turn_number if battle != null else 0,
		"team_hp": team_hp,
		"opponent_hp": opponent_hp,
	}
