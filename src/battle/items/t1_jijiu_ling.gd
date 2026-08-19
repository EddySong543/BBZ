extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_base_attack_aftereffect(player, data)

func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, _events: Array) -> void:
	if not bool(context.get("connected", false)):
		return
	var target: int = battle.lowest_hp_living_hero(player)
	if target >= 0:
		battle._heal(player, target, int(data.params.get("heal", 2)))
