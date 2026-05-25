extends HeroSkillV4

## h13 愚者【孤注一掷】主动 2 能 · 单英雄（娱乐流旗舰）
## 豪赌一击：66% 伤害翻倍（2.0 → 4.0），34% 维持 2.0。穿"防"、被"大防"挡。
## 需可复现 RNG（走 battle.rng；联机/录像/测试确定）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "guzhu"

func active_cost(_battle: BattleEngineV4, _player: int, _slot: int) -> int:
	return 2

func active_is_attack() -> bool:
	return true

func active_attack_kind() -> int:
	return ActionDefV4.Action.BIG_ATTACK   # 穿"防"、被"大防"挡

func active_attack_damage(battle: BattleEngineV4, _player: int, _slot: int) -> int:
	var base: int = 2 * ActionDefV4.HP_UNIT   # 2.0
	return base * 2 if battle.rng.randf() < 0.66 else base
