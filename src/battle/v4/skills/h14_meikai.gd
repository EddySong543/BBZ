extends HeroSkillV4

## h14 魔术师【梅开二度】主动 2 能 · cap 2 · 单英雄
## 保存效果：使本英雄【下一个动作】执行 2 次（波/大波/防/大防/攒；不含切换、不含主动技）。
## flag 跨切换保留；切换不消耗也不被复制。复制逻辑由引擎读 statuses["meikai"] 处理。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "meikai"

func active_cost(_battle: BattleEngineV4, _player: int, _slot: int) -> int:
	return 2

func active_per_game_cap() -> int:
	return 2

func execute_active(battle: BattleEngineV4, player: int, slot: int) -> void:
	battle.set_status(player, slot, "meikai", true)
