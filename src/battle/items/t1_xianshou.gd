extends ItemEffect

## 先手：你这次攻击 +0.5 伤（动作修正器）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "atk_bonus", int(data.params.get("bonus", 1)))
