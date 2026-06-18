extends ItemEffect

## 吸血鬼的獠牙：你这次攻击命中（穿过防御门连接）时回 0.5 HP。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.add_item_rider(player, _data)

func on_attack_connect(battle: BattleCore, player: int, _target_player: int, _target_slot: int, _dealt: int, data: ItemData) -> void:
	battle._heal(player, battle.active_index[player], int(data.params.get("heal", 1)))
