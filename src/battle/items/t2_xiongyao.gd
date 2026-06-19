extends ItemEffect

## 凶药：弃 0.5 HP，你这次攻击 +1.0 伤（HP→攻导出·豪赌；血不足则不发动、不自尽）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var pay: int = int(data.params.get("pay", 1))
	if battle.hp[player][target] > pay:
		battle.hp[player][target] -= pay
		battle.add_item_mod(player, "atk_bonus", int(data.params.get("bonus", 2)))
