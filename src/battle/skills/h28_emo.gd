extends HeroSkill

## h28 恶魔【灵魂契约】被动 · 开局缔约 · 团队层
## 开局指定一名队友缔约 → 该队友所有攻击(波/大波/攻击型主动技) +1.0；其每次攻击恶魔 -1.0 HP；
##   持续到恶魔或该队友死亡。
## ⚠️ 契约对象由玩家开局指定；无 UI → 默认指定槽位最小的队友。

func on_setup(battle: BattleCore, player: int, slot: int) -> void:
	for i in range(battle.heroes[player].size()):
		if i != slot:
			battle.link[player]["contract"] = i
			battle.link[player]["demon"] = slot
			return


func modify_team_outgoing_damage(dmg: int, action: int, battle: BattleCore, _attacker_player: int, attacker_slot: int, self_player: int, self_slot: int) -> int:
	if action != ActionDef.Action.ATTACK and action != ActionDef.Action.BIG_ATTACK:
		return dmg
	var contract: int = int(battle.link[self_player].get("contract", -1))
	# 仅当攻击者=契约对象、恶魔(self)存活时：队友 +1.0，恶魔付 1.0 HP。
	if contract >= 0 and attacker_slot == contract and battle.hp[self_player][self_slot] > 0:
		battle.hp[self_player][self_slot] -= ActionDef.HP_UNIT
		return dmg + ActionDef.HP_UNIT
	return dmg
