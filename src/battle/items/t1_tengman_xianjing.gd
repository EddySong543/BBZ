extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.item_debuff_blocked(1 - player):
		return
	battle.arm_switch_out_trap(1 - player, player, int(data.params.get("damage", 2)))
