extends HeroSkillV4

## h23 命运之轮【周而复始】被动 · 单英雄
## 每次登场（开局首发 + 每次切换上场）随机抽 1 祝福：
##   攻+1（在场期间）/ 受伤-1（在场期间）/ 1.0 盾（一次性）/ +1 能（立即入团队池）。
## 下场清在场型 buff（攻/防），盾与能量已落地不清。需可复现 RNG（走 battle.rng）。

func on_setup(battle: BattleEngineV4, player: int, slot: int) -> void:
	# 开局首发英雄视为"登场"，抽一次。
	if slot == battle.active_index[player]:
		_roll(battle, player, slot)


func on_switch_in(battle: BattleEngineV4, player: int, slot: int) -> void:
	_roll(battle, player, slot)


func on_switch_out(battle: BattleEngineV4, player: int, slot: int) -> void:
	battle.set_status(player, slot, "wheel_atk", false)
	battle.set_status(player, slot, "wheel_def", false)


func modify_outgoing_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	if battle.get_status(player, slot, "wheel_atk", false):
		return dmg + ActionDefV4.HP_UNIT
	return dmg


func modify_incoming_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int, _attacker_player: int) -> int:
	if battle.get_status(player, slot, "wheel_def", false):
		return maxi(dmg - ActionDefV4.HP_UNIT, 0)
	return dmg


func _roll(battle: BattleEngineV4, player: int, slot: int) -> void:
	# 重抽前清在场型 buff，避免叠加。
	battle.set_status(player, slot, "wheel_atk", false)
	battle.set_status(player, slot, "wheel_def", false)
	match battle.rng.randi_range(0, 3):
		0:
			battle.set_status(player, slot, "wheel_atk", true)
		1:
			battle.set_status(player, slot, "wheel_def", true)
		2:
			battle.shield[player][slot] += ActionDefV4.HP_UNIT
		3:
			battle.energy[player] = mini(battle.energy[player] + 1, ActionDefV4.MAX_ENERGY)
