extends ItemEffect

## 噬心钉〔遗物〕：攻击 +1.0 伤，但你无法防御（→ 纯小子 / 富人思维）。
func relic_pre(battle: BattleCore, player: int, data: ItemData, _state: Dictionary) -> void:
	battle.add_item_mod(player, "atk_bonus", int(data.params.get("bonus", 2)))
	battle.set_item_mod(player, "self_no_defend", 1)
