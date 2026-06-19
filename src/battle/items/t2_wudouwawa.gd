extends ItemEffect

## 巫毒娃娃：放一个 HP1 替身，下次受伤由它吃下（吸收上限 1.0、溢出穿过、挨一下即碎）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.set_status(player, target, "decoy_hp", int(data.params.get("hp", 2)))
