extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.request_energy_equalize(player)
