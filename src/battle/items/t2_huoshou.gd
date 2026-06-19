extends ItemEffect

## 秘银充能护手：你攻击命中时 +0.5 能（攻→能导出）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_rider(player, data)

func on_attack_connect(battle: BattleCore, player: int, _target_player: int, _target_slot: int, _dealt: int, data: ItemData) -> void:
	battle._gain_energy(player, int(data.params.get("energy", 1)))
