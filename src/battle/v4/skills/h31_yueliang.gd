extends HeroSkillV4

## h31 月亮【阴晴圆缺】被动 · 单英雄（全局回合公开循环）
## 四相循环（turn_number % 4）：阴(0)=造成伤害减半 / 晴(1)=造成翻倍 / 圆(2)=受到减半 / 缺(3)=受到翻倍。
## 仅月亮出战时其效果生效（hook 只对出战触发）；相位随全局回合公开推进。减半=整数半点 ÷2（沿用 0.5 档）。

func modify_outgoing_damage(dmg: int, _action: int, battle: BattleEngineV4, _player: int, _slot: int) -> int:
	match battle.turn_number % 4:
		0:
			return dmg / 2   # 阴：造成减半
		1:
			return dmg * 2   # 晴：造成翻倍
	return dmg


func modify_incoming_damage(dmg: int, _action: int, battle: BattleEngineV4, _player: int, _slot: int, _attacker_player: int) -> int:
	match battle.turn_number % 4:
		2:
			return dmg / 2   # 圆：受到减半
		3:
			return dmg * 2   # 缺：受到翻倍
	return dmg
