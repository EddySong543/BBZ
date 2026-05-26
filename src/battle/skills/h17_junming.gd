extends HeroSkill

## h17 皇帝【君命难违】主动 2 能 · 无 cap · 单英雄（作用对手下回合）
## 敕令对手下回合禁用一个动作系列（攻击系 波+大波 / 防御系 防+大防）二选一；攒/切换不可禁。
##
## ⚠️ "二选一"是玩家决策；当前无 UI → 默认禁"攻击系"(0)。UI 接入后由玩家选 0/1。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "junming"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 2

func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var opp: int = 1 - player
	battle.disabled_group[opp] = 0                          # 默认禁攻击系
	battle._disabled_on_turn[opp] = battle.turn_number + 1  # 作用对手下回合
