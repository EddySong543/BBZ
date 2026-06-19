extends ItemEffect

## 丘比特之箭：你这次攻击无视对手护甲层（穿甲·#4；仍受"挡不挡"约束）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "pierce_armor", true)
