extends ItemEffect

## 随身熔炉：烧掉你一件未使用的库存道具，立即 +0.5 能（满手废牌的退出口）。
## 从道具槽 slots 里找一件【已就绪·未用·非本件】的道具烧掉，给能量。找不到则不发动（不白给能量）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var sl: Array = battle.slots[player]
	for s in sl:
		var it = s.get("item", null)
		if it != null and it.item_id != data.item_id and not bool(s.get("used", false)):
			s["item"] = null
			s["used"] = true
			battle._gain_energy(player, int(data.params.get("energy", 1)))
			return
