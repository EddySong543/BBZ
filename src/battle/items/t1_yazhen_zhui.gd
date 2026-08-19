extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "bigdef_blocks_wave_energy_loss", int(data.params.get("energy_loss", 2)))
