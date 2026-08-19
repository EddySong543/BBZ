extends ItemEffect


func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	return battle.is_living_reserve(player, target) \
		and (battle.heroes[player][target] as HeroData).hero_id in ["h06", "h10", "h20"]


func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	battle.arm_borrowed_mark(player, target)
