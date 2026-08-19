extends ItemEffect

## 还魂丹：每名英雄整局只能使用一次；保险未触发前永久保留。
func can_use(battle: BattleCore, player: int, target: int, _data: ItemData) -> bool:
	if int(battle.get_status(player, target, "huanhun_used", 0)) > 0:
		return false
	for use_variant in battle.item_uses[player]:
		var use: Dictionary = use_variant
		var queued: ItemData = use.get("data", null)
		if queued != null and queued.item_id == "t2_huanhundan" \
				and int(use.get("target", -1)) == target:
			return false
	return true


func on_consumed(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	battle.set_status(player, target, "huanhun_used", 1)


func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	battle.set_status(player, target, "fatal_damage_immunity", 1)
