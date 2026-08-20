extends ItemEffect


func prepare_pre(battle: BattleCore, _player: int, _target: int, _data: ItemData) -> void:
	for side in [0, 1]:
		battle.set_item_mod(side, "global_skill_silence", true)
