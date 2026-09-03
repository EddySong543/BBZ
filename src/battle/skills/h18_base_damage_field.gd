extends HeroSkill

## h18 相柳【游丝引】被动 · 控制 · HP5
## 相柳出战时，双方「波」与「大波」的基础伤害均视为 1 点。
##
## 规则边界：
##   - 只改 ActionDef 基础值；强化波、攻击总修正、毒素、印记与脆弱随后照常结算。
##   - 大波仍穿「防」并被「大防」挡住；h13 拆分大波的两段各自按 1 点基础伤害结算。
##   - 攻击型主动技、追击、反击与其他独立伤害不受影响。
##   - 仅相柳存活、出战且技能有效时生效；双方相柳同时出战也不会叠加。


func modify_battlefield_base_attack_damage(dmg: int, action: int, _battle: BattleCore,
		_attacker_player: int, _attacker_slot: int, _self_player: int, _self_slot: int) -> int:
	return ActionDef.HP_UNIT if ActionDef.is_attack(action) else dmg


func battlefield_damage_number_state(before_damage: int, after_damage: int, action: int,
		_battle: BattleCore, _attacker_player: int, _attacker_slot: int,
		_self_player: int, _self_slot: int) -> StringName:
	return &"limited" if ActionDef.is_attack(action) and after_damage < before_damage else &"normal"
