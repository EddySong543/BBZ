extends ItemEffect

## 点金石〔一次性〕：立即把你一件 T1 道具升为 T2（免部署锁 + 定向你选、不走随机 3 选 1）。
## 从道具槽 slots 里找一件 T1 道具，原地换成它的升级件（upgrade_to）。找不到 / 无升级线则不发动。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var sl: Array = battle.slots[player]
	for s in sl:
		var it = s.get("item", null)
		if it != null and int(it.tier) == 1 and String(it.upgrade_to) != "":
			var up = ItemCatalog.make(it.upgrade_to)
			if up != null:
				s["item"] = up
				return
