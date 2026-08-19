extends ItemEffect


func setup_pre(battle: BattleCore, player: int, _data: ItemData) -> void:
	battle.request_tianluo(player)


func resolves_before_hostile_item_counters() -> bool:
	return true
