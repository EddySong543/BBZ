extends ItemEffect

## 护身符：本回合免疫对手对你的一次 debuff / 干扰（符护其身·setup_pre 先于任何 debuff 落地）。
func setup_pre(battle: BattleCore, player: int, data: ItemData) -> void:
	battle.set_item_mod(player, "immune", int(data.params.get("immune", 1)))
