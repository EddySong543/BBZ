extends HeroSkillV4

## h24 正义【天平归衡】主动 2 能 · cap 2 · 单英雄（作用正义 + 对手出战）
## 将正义与对手出战英雄 HP 拉到平均（非伤害，绕过防御/护盾）。各自不超上限。
## ⚠️ 扶倾(伤前拨平,可救命) / 清算(伤+死亡判定后拨平) 由玩家选时机；无 UI → 默认扶倾
##   （即时执行于 Phase 2.6，在本回合伤害之前）。清算时机待 UI 接入。
## 平均落整数半点（(a+b)/2 向下取整，沿用 0.5 档）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "tianping"

func active_cost(_battle: BattleEngineV4, _player: int, _slot: int) -> int:
	return 2

func active_per_game_cap() -> int:
	return 2

func execute_active(battle: BattleEngineV4, player: int, slot: int) -> void:
	var opp: int = 1 - player
	var os: int = battle.active_index[opp]
	var avg: int = (battle.hp[player][slot] + battle.hp[opp][os]) / 2
	battle.hp[player][slot] = mini(avg, battle.max_hp[player][slot])
	battle.hp[opp][os] = mini(avg, battle.max_hp[opp][os])
