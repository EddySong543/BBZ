extends HeroSkill

## h02 牛金【玄金不动相】被动 · 防御 · HP7。
## 牛金挡下「波」或「大波」后，己方下一次「波」升级为「大波」。
##
## 升级是不过期、不叠加的团队资源：换人、牛金退场或阵亡都不清除。
## 只有下一次基础「波」会兑现并消费；普通「大波」、攻击型主动技、道具伤害均不消费。
## 升级波仍按波付费、记动作和接受道具判断，但 hit 的伤害、有效类型与基础穿透按大波；
## 被道具判定落空或被大防挡住仍会消费，疾风复制出的两段共享同一次升级。
##
## 触发只认对手实际选择的基础「波」/「大波」且本次确实被挡下。道具 hit、攻击型主动技不触发；
## 大防挡波属于成功挡下，防没有挡住大波则不会进入 on_block。
func on_block(battle: BattleCore, player: int, _slot: int, attacker_player: int,
		_attack_action: int, _defense_action: int, _raw: int, src: String) -> void:
	if src != "action" or not ActionDef.is_attack(battle.selected_action[attacker_player]):
		return
	battle.upgrade_next_wave[player] = true
