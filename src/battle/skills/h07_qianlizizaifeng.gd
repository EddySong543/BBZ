extends HeroSkill

## h07 星日【千里自在风】· 切换
## ① 每回合一次，涉及星日的切换不占动作槽；
## ② 星日切换登场时，对敌方出战造成 0.5 冲撞伤；独立伤害不算命中。

func has_free_switch() -> bool:
	return true


func free_switch_cap() -> int:
	return 1


func on_switch_in(battle: BattleCore, player: int, _slot: int) -> void:
	battle.chongzhuang(player)
