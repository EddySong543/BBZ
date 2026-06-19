extends ItemEffect

## 不动明王甲〔遗物〕：防御成功回 0.5 HP 且 +0.5 能，但攻击 −0.5（→ 盾狗）。
func relic_pre(battle: BattleCore, player: int, _data: ItemData, _state: Dictionary) -> void:
	battle.add_item_mod(player, "atk_penalty", 1)
	battle.set_item_mod(player, "block_energy", 1)
	battle.set_item_mod(player, "block_heal", 1)
