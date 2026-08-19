extends ItemEffect

## 后手：敌方原选基础攻击时，待攻击结算后给仍存活的我方出战英雄 1.5 护盾。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.will_attack_this_turn(1 - player):
		battle.add_item_mod(player, "survive_attack_shield", int(data.params.get("armor", 3)))
