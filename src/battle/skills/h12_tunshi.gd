extends HeroSkill

## h12 亥猪【吞噬】主动 0 能 · cap 3 · 单英雄
## 发动一次"波"（1.0），命中实际伤害回复等量 HP（被格挡部分不回，回血不超上限）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "tunshi"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0

func active_per_game_cap() -> int:
	return 3

func active_is_attack() -> bool:
	return true

func active_attack_damage(_battle: BattleCore, _player: int, _slot: int) -> int:
	return ActionDef.get_base_damage(ActionDef.Action.ATTACK)   # 1.0

func active_attack_kind() -> int:
	return ActionDef.Action.ATTACK   # 被"防"挡

func on_active_attack_resolved(battle: BattleCore, player: int, slot: int, dealt: int) -> void:
	if dealt > 0:
		battle._heal(player, slot, dealt)   # _heal 内含燃烧禁疗判定
