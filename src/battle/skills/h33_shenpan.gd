extends HeroSkill

## h33 审判【最后审判】主动 2 能 · cap 2 · 单英雄（作用对手出战）
## 处决对手出战英雄：若其 HP ≤ 2.0 → 直接归零（穿透防御/护盾/减免）；HP>2.0 无效（仍消耗能量与动作）。
## 在对手切换/回血之后判定（执行点已移到 Phase 2.6，切换之后）。处决不触发 on_kill。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "shenpan"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 2

func active_per_game_cap() -> int:
	return 2

func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var opp: int = 1 - player
	var os: int = battle.active_index[opp]
	if battle.hp[opp][os] > 0 and battle.hp[opp][os] <= 2 * ActionDef.HP_UNIT:
		battle.hp[opp][os] = 0   # 处决
