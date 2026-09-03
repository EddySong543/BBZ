extends HeroSkill

## h10 昴日【飞洒天星】· 状态（基础攻击强化）
## 己方任一攻击命中敌方 → 全队 +1 层剑气（公开、跨回合、切换保留、cap 4）。
## 只有昴日出战时能主动选择消费：2–3 点只能强化「波」穿防，4 点可强化「波 / 大波」穿大防。
## 不增加伤害、不另收费；攻击形成时先清空旧剑气，若命中再按普通攻击重新积累 1 点。

const CAP := 4
func on_team_deal_hit(battle: BattleCore, player: int, slot: int, _attacker_slot: int, _target_player: int, _target_slot: int, _dealt: int) -> void:
	var j: int = int(battle.get_team_status(player, "jianqi", 0))
	if j >= CAP:
		return   # 剑气已满 → 不再累积 → 不算 combo proc
	battle.set_team_status(player, "jianqi", j + 1)


func enables_jianqi_attack() -> bool:
	return true
