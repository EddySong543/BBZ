extends HeroSkill

## h07 星日【一骑当先】· 节奏
## ① 涉及马的切换不占动作槽、不限次数（免费切换；free_switch_cap 默认 -1 = 无限）；
## ② 马切换登场时，对敌方出战造成 0.5 冲撞伤，并触发 on-hit（引爆蛇毒 / 喂鸡剑气）。

func has_free_switch() -> bool:
	return true


func on_switch_in(battle: BattleCore, player: int, _slot: int) -> void:
	battle.chongzhuang(player)
