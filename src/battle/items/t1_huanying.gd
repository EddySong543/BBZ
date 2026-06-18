extends ItemEffect

## 幻影：你的道具栏对对手多显示 1 个假道具，持续到你下次用道具（污染己方公开信息·诈唬）。
func setup_pre(battle: BattleCore, player: int, _data: ItemData) -> void:
	battle.info_distortion[player]["fake"] = int(battle.info_distortion[player].get("fake", 0)) + 1
