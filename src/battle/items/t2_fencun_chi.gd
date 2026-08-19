extends ItemEffect

func prepare_pre(battle: BattleCore, _player: int, _target: int, data: ItemData) -> void:
	var cap: int = int(data.params.get("cap", 2))
	for side in [0, 1]:
		var current: int = int(battle.item_mod(side, "base_attack_damage_cap", cap))
		battle.set_item_mod(side, "base_attack_damage_cap", mini(current, cap))
		battle.set_item_mod(side, "base_attack_damage_cap_remaining", mini(current, cap))
