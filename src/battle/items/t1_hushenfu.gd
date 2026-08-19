extends ItemEffect

## 圣贤书：敌方对我方施加的第一个非伤害道具效果无效。
func setup_pre(battle: BattleCore, player: int, data: ItemData) -> void:
	battle.add_item_mod(player, "immune", int(data.params.get("immune", 1)))
