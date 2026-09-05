extends HeroSkill

## h07 星日【千里快哉风】· 切换
## ① 每回合一次，任一端为星日的主动切换不占动作槽；切入与切出共用这一次数；
## ② 星日完成登场后，对敌方出战造成 0.5 独立伤害；不算命中。

func has_free_switch() -> bool:
	return true


func free_switch_cap() -> int:
	return 1


func on_switch_in(battle: BattleCore, player: int, _slot: int, events: Array = []) -> void:
	battle.chongzhuang(player, events)
