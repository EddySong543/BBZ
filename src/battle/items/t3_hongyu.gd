extends ItemEffect

## 渴血红玉：弃 2.0 HP，本回合你的攻击翻倍（以血换刃·豪赌；血不足则不发动）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var pay: int = int(data.params.get("pay", 4))
	if battle.hp[player][target] > pay:
		battle.hp[player][target] -= pay
		battle.set_item_mod(player, "atk_mult", 2)
