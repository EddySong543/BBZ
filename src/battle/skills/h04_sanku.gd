extends HeroSkill

## h04 卯兔【三窟】被动 · 单英雄
## 每次切换下场 +1 窟层（cap 3）；受伤时消 1 层、该次伤害 -1.0（"吸收后消耗1层"）。
## 窟层随英雄保留（statuses 持久，切换不清）。一次受伤消一层。

const MAX_KU := 3


func on_switch_out(battle: BattleCore, player: int, slot: int) -> void:
	var ku: int = int(battle.get_status(player, slot, "ku", 0))
	battle.set_status(player, slot, "ku", mini(ku + 1, MAX_KU))


func modify_incoming_damage(dmg: int, _action: int, battle: BattleCore, player: int, slot: int, _attacker_player: int) -> int:
	if dmg <= 0:
		return dmg
	var ku: int = int(battle.get_status(player, slot, "ku", 0))
	if ku > 0:
		battle.set_status(player, slot, "ku", ku - 1)
		return maxi(dmg - ActionDef.HP_UNIT, 0)
	return dmg
