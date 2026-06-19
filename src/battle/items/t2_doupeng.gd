extends ItemEffect

## 迷雾斗篷：你的道具栏对对手全部隐藏，持续到你下次用道具（迷雾的强版·全藏）。
func setup_pre(battle: BattleCore, player: int, _data: ItemData) -> void:
	battle.info_distortion[player]["hide_all"] = true
