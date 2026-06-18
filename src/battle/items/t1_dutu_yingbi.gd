extends ItemEffect

## 赌徒的硬币：抛币——正面这次攻击 +1.0 伤、反面落空（动作清零）。赌自己、不抹对手的读。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.rng.randf() < 0.5:
		battle.add_item_mod(player, "atk_bonus", int(data.params.get("win", 2)))
	else:
		battle.set_item_mod(player, "atk_nullify", true)
