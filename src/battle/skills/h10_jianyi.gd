extends HeroSkill

## h10 酉鸡【剑意·以意御剑】· 状态（主动技：拔剑一闪）
## 己方任一攻击命中敌方 → 鸡 +1 层剑气（公开、跨回合、cap 4；存 鸡 自己 slot 的 "jianqi"）。
##   （on_team_deal_hit 对全队触发，但只有鸡 override → 只有鸡 slot 累积；虎双段 → +2。）
## 拔剑一闪 = 出战时攻击型主动技（0 能）：伤害 = 波 + 剑气×0.5；
##   剑气 ≥2 → 穿防、满 4 → 穿大防；命中后清空剑气（一闪那击不自累积）。

const CAP := 4

func on_team_deal_hit(battle: BattleCore, player: int, slot: int, _attacker_slot: int, _target_player: int, _target_slot: int, _dealt: int) -> void:
	var j: int = int(battle.get_status(player, slot, "jianqi", 0))
	battle.set_status(player, slot, "jianqi", mini(CAP, j + 1))


func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "bajian"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0

func active_is_attack() -> bool:
	return true

func can_use_active(battle: BattleCore, player: int, slot: int) -> bool:
	return int(battle.get_status(player, slot, "jianqi", 0)) > 0

func active_attack_damage(battle: BattleCore, player: int, slot: int) -> int:
	var j: int = int(battle.get_status(player, slot, "jianqi", 0))
	return ActionDef.get_base_damage(ActionDef.Action.ATTACK) + j   # 波(2半) + 每层 1 半点(0.5HP)

func attack_penetration(base_pen: int, _action: int, battle: BattleCore, player: int, slot: int) -> int:
	var j: int = int(battle.get_status(player, slot, "jianqi", 0))
	if j >= 4:
		return ActionDef.Pen.PIERCE_BIGDEF
	if j >= 2:
		return ActionDef.Pen.PIERCE_DEF
	return base_pen

func on_active_attack_resolved(battle: BattleCore, player: int, slot: int, _dealt: int) -> void:
	battle.set_status(player, slot, "jianqi", 0)   # 一闪消耗全部剑气
