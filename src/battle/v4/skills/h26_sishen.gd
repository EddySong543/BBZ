extends HeroSkillV4

## h26 死神【向死而生】主动 4 能 · cap 1 · 单英雄（变身/双形态）
## 消耗 4 能变身「收割」形态（不可逆，每局 1 次）：此后所有伤害 +1.0、击杀敌方英雄回 2.0 HP。
## 变身前「待渡」普通形态。form 存引擎 form[player][slot]（随英雄保留）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "sishen"

func active_cost(_battle: BattleEngineV4, _player: int, _slot: int) -> int:
	return 4

func active_per_game_cap() -> int:
	return 1

func execute_active(battle: BattleEngineV4, player: int, slot: int) -> void:
	battle.form[player][slot] = 1   # 变身「收割」

func modify_outgoing_damage(dmg: int, _action: int, battle: BattleEngineV4, player: int, slot: int) -> int:
	if battle.form[player][slot] == 1:
		return dmg + ActionDefV4.HP_UNIT   # 收割形态所有伤害 +1.0
	return dmg

func on_kill(_victim_player: int, _victim_slot: int, _overkill: int, battle: BattleEngineV4, player: int, slot: int) -> void:
	if battle.form[player][slot] == 1:
		battle._heal(player, slot, 2 * ActionDefV4.HP_UNIT)   # 击杀回 2.0
