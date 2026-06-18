extends ItemEffect

## 迷雾：你的 1 个道具对对手隐藏，持续到你下次用道具（幻影的反面·藏真打突袭）。
func setup_pre(battle: BattleCore, player: int, _data: ItemData) -> void:
	battle.info_distortion[player]["hidden"] = int(battle.info_distortion[player].get("hidden", 0)) + 1
