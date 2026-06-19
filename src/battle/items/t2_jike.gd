extends ItemEffect

## 扭曲的饥渴：你这次攻击命中时回 1.0 HP（攻→防导出·PvE 值钱）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_rider(player, data)

func on_attack_connect(battle: BattleCore, player: int, _target_player: int, _target_slot: int, _dealt: int, data: ItemData) -> void:
	battle._heal(player, battle.active_index[player], int(data.params.get("heal", 2)))
