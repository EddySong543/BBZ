extends HeroSkill

## h15 女祭司【三缄其口】主动 1 能 · cap 3 · 单英雄（作用对手出战）
## 沉默对手出战英雄 2 回合：其被动 hook 失效，期间已有叠层冻结（不增长也不清零）。仅对手出战位。
## 沉默 = 置 silenced_until = 当前回合 + 1，引擎触发其被动 hook 前检查跳过（见 _is_silenced）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "sanjian"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 1

func active_per_game_cap() -> int:
	return 3

func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var opp: int = 1 - player
	var os: int = battle.active_index[opp]
	battle.set_status(opp, os, "silenced_until", battle.turn_number + 1)   # 沉默本回合 + 下回合 = 2 回合
