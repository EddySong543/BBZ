extends HeroSkill

## h15 女祭司【三缄其口】主动 1 能 · cap 3 · 单英雄（作用对手出战）
## 沉默对手出战英雄（其被动本回合失效）+ 抹除其已累积的叠层增益。仅本回合、仅对手出战位。
## 沉默 = 置 silenced_turn=当前回合，引擎触发其被动 hook 前检查跳过（见 _is_silenced）。

const STACK_KEYS := ["combo", "ku", "xuexue", "yinzhe_atk", "wheel_atk", "wheel_def", "charge_up"]


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
	battle.set_status(opp, os, "silenced_turn", battle.turn_number)   # 本回合沉默
	for k in STACK_KEYS:
		battle.statuses[opp][os].erase(k)                             # 抹除叠层增益
