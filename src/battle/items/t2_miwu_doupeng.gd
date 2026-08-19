extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.info_distortion[player]["hide_item_bar"] = true
