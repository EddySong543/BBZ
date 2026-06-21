extends HeroSkill

## h14 黑暗丑牛【劈穿】被动 · 进攻 · HP6
## 黑暗丑牛的攻击造成击杀【溢出穿透】：一斧劈死敌方出战英雄且有溢出伤害时，
## 溢出穿透到【被迫登场的下一名】敌方英雄（势如破竹）。
## overkill 由引擎在 on_kill 预算（= 造成伤害 − 被杀者击杀前剩余 HP·半点）；
## 引擎把溢出劈向该方最高血存活替补（= choose_death_switch 补位选择 → 命中其真正顶上的英雄）。
## 溢出只来自首次一斧、不链式（劈死的替补不再触发本机制·避免无限滚雪球）。
##
## 设计依据（heroes-redesign / build-design-framework）：超杀 / 溢杀原语（heroes-schools §5.4
##   ⭐保留给进攻 slot·首用）。dark-mirror = 磐牛 h02"挡下反弹" → 黑牛"一斧劈穿"。

func on_kill(victim_player: int, _victim_slot: int, overkill: int, battle: BattleCore, _player: int, _slot: int) -> void:
	if overkill > 0:
		battle.carry_overkill_to_next(victim_player, overkill)
