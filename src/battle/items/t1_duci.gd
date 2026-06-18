extends ItemEffect

## 毒刺：你这次攻击命中则给目标 +1 层毒（D2=蛇引爆毒·任意攻击引爆）；本身不直接造伤。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.add_item_rider(player, _data)

func on_attack_connect(battle: BattleCore, _player: int, target_player: int, target_slot: int, _dealt: int, data: ItemData) -> void:
	var cur: int = int(battle.get_status(target_player, target_slot, "poison", 0))
	battle.set_status(target_player, target_slot, "poison", cur + int(data.params.get("poison", 1)))
