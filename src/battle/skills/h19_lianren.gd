extends HeroSkill

## h19 恋人【至死不渝】被动 · 单英雄（绑定挚爱存亡）
## 开局指定挚爱：挚爱存活时恋人受伤 -1.0；挚爱阵亡瞬间恋人立即受 3.0（穿透防御/护盾）。
##
## ⚠️ "挚爱"由玩家开局指定；当前无 UI → 默认指定槽位最小的非自己队友。
##   挚爱关系存恋人自己槽位 statuses["beloved"]。

const SUNK_DMG := 3 * ActionDef.HP_UNIT   # 殉情 3.0


func on_setup(battle: BattleCore, player: int, slot: int) -> void:
	for i in range(battle.heroes[player].size()):
		if i != slot:
			battle.statuses[player][slot]["beloved"] = i
			return


func modify_incoming_damage(dmg: int, _action: int, battle: BattleCore, player: int, slot: int, _attacker_player: int) -> int:
	var beloved: int = int(battle.get_status(player, slot, "beloved", -1))
	if beloved >= 0 and battle.hp[player][beloved] > 0:
		return maxi(dmg - ActionDef.HP_UNIT, 0)
	return dmg


func on_ally_death(dead_slot: int, battle: BattleCore, player: int, slot: int) -> void:
	if dead_slot == int(battle.get_status(player, slot, "beloved", -1)):
		battle.hp[player][slot] -= SUNK_DMG   # 殉情，穿透直接扣
