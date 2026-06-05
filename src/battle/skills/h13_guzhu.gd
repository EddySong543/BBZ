extends HeroSkill

## h13 愚者【孤注一掷】主动 2 能 · 单英雄（娱乐流旗舰 · buff 型豪赌）
## 发动挂「孤注」buff（占动作槽、本身不攻击）→ 之后【下一次任意攻击】（波/大波）结算时
##   66% 概率伤害翻倍、34% 维持原样，buff 消耗（无论是否翻倍）。
## 是否穿防取决于该次攻击本身（波被"防"挡 / 大波穿"防"）。
## 翻倍发生在出伤修正阶段（base×2，再过防御门/减伤）。需可复现 RNG（走 battle.rng）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "guzhu"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 2

func execute_active(battle: BattleCore, player: int, slot: int) -> void:
	battle.set_status(player, slot, "guzhu_buff", true)   # 挂翻倍 buff，待下次攻击兑现

func modify_outgoing_damage(dmg: int, _action: int, battle: BattleCore, player: int, slot: int) -> int:
	# modify_outgoing 仅在攻击动作(波/大波)被引擎调用 → 即「下一次攻击」。
	if battle.get_status(player, slot, "guzhu_buff", false):
		battle.set_status(player, slot, "guzhu_buff", false)   # 一次性消耗
		if battle.rng.randf() < 0.66:
			return dmg * 2
	return dmg
