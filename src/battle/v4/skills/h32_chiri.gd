extends HeroSkillV4

## h32 太阳【赤日流金】主动 1 能 · cap 3 · 单英雄（作用对手出战）
## 灼烧对手出战英雄 → "燃烧"（2 回合）：期间禁回血 + 受到攻击 +1.0（易伤）；随英雄切换保留。
## 燃烧的效果（易伤 / 禁疗 / 时长 tick）全部在引擎按 statuses["burn"] 驱动；本组件只负责附着。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "chiri"

func active_cost(_battle: BattleEngineV4, _player: int, _slot: int) -> int:
	return 1

func active_per_game_cap() -> int:
	return 3

func execute_active(battle: BattleEngineV4, player: int, _slot: int) -> void:
	var opp: int = 1 - player
	battle.set_status(opp, battle.active_index[opp], "burn", 2)
