extends HeroSkill

## h10 昴日【飞洒天星】· 状态（攻击型主动技）
## 己方任一攻击命中敌方 → 全队 +1 层剑气（公开、跨回合、切换保留、cap 4）。
##   （只有昴日能发动飞洒天星消费它；双生／三花可额外触发英雄技能。）
## 飞洒天星 = 出战时攻击型主动技（费 2 能·2026-07-05 平衡：1→2 能·510 局验收卷 63.6% 仍全场第二·
##   2 能后满层账面（3 血穿大防）仍优于大波（3 能 2 血穿防）→ 保引擎身份不掉入"有技能不用"区；
##   下一刀若仍 >60% 走效率端（穿透阈值/每层伤害），⛔不再加费——3 能=比肩大波·引擎身份消失）：
##   伤害 = 波 + 剑气×0.5；剑气 ≥2 → 穿防、满 4 → 穿大防；命中后清空剑气（主动攻击不自累积）。

const CAP := 4
const ACTIVE_COST := 4   # 4 半能 = 2 能（2026-07-05 由 1 能调升·Eddy 批·历史：0→1 于 2026-07-04）

func on_team_deal_hit(battle: BattleCore, player: int, slot: int, _attacker_slot: int, _target_player: int, _target_slot: int, _dealt: int) -> void:
	var j: int = int(battle.get_team_status(player, "jianqi", 0))
	if j >= CAP:
		return   # 剑气已满 → 不再累积 → 不算 combo proc
	battle.set_team_status(player, "jianqi", j + 1)


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return ACTIVE_COST

func active_is_attack() -> bool:
	return true

func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return int(battle.get_team_status(player, "jianqi", 0)) > 0

func active_attack_damage(battle: BattleCore, player: int, _slot: int) -> int:
	var j: int = int(battle.get_team_status(player, "jianqi", 0))
	return ActionDef.get_base_damage(ActionDef.Action.ATTACK) + j   # 波(2半) + 每层 1 半点(0.5HP)

func attack_penetration(base_pen: int, _action: int, battle: BattleCore, player: int, _slot: int) -> int:
	var j: int = int(battle.get_team_status(player, "jianqi", 0))
	if j >= 4:
		return ActionDef.Pen.PIERCE_BIGDEF
	if j >= 2:
		return ActionDef.Pen.PIERCE_DEF
	return base_pen

func on_active_attack_resolved(battle: BattleCore, player: int, _slot: int, _dealt: int) -> void:
	battle.set_team_status(player, "jianqi", 0)   # 飞洒天星消耗全队唯一一份剑气
