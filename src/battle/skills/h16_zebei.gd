extends HeroSkill

## h16 皇后【泽被苍生】主动 2 能 · cap 3 · 单英雄（效果作用全队含替补）
## 全队（出战 + 2 替补）各回复 1.0 HP（不超上限，不复活已阵亡者）。

func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "zebei"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 2

func active_per_game_cap() -> int:
	return 3

func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	for i in range(battle.hp[player].size()):
		if battle.hp[player][i] > 0:   # 不复活死者；_heal 内含燃烧禁疗判定
			battle._heal(player, i, ActionDef.HP_UNIT)
