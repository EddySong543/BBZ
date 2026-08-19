extends ItemEffect

func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var recipient: int = battle.lowest_hp_living_hero(player, target)
	if recipient < 0:
		return
	var events: Array = []
	var hp_before: int = battle.hp[player][target]
	battle.lose_life(player, target, int(data.params.get("loss", 2)), events,
		"t1_xuedu_jie")
	battle.queue_item_events(player, events)
	# 还魂丹抵消致命支付仍算成功兑现；已在更早一件血渡结中死亡则不能零成本续疗。
	if hp_before > 0:
		battle._heal(player, recipient, int(data.params.get("heal", 4)))
