extends HeroSkillV4

## h01 子鼠【窃运】主动 0 能 · 单英雄
## 偷对手 1 能（对手团队池 -1 / 己方池 +1），每局 cap 3。对手 0 能时无效果（仍消耗一次动作）。
## cap 由引擎统一计数（statuses["active_uses"]）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "qieyun"

func active_cost(_battle: BattleEngineV4, _player: int, _slot: int) -> int:
	return 0

func active_per_game_cap() -> int:
	return 3

func execute_active(battle: BattleEngineV4, player: int, _slot: int) -> void:
	var opp: int = 1 - player
	if battle.energy[opp] > 0:
		battle.energy[opp] -= 1
		battle.energy[player] = mini(battle.energy[player] + 1, ActionDefV4.MAX_ENERGY)
