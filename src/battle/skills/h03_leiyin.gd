extends HeroSkill

## h03 尾火【白额雷音】被动 · 进攻 · HP5
## 每失去2点生命，自己结算「波 / 大波」时增加1点伤害。
## 只读取攻击形成时的当前生命；不强化道具、主动技、追击或反击。

const HP_POINT := 2
const LOST_HEALTH_PER_BONUS := 2 * HP_POINT
const DAMAGE_PER_BONUS := HP_POINT


func modify_outgoing_damage(dmg: int, action: int, battle: BattleCore,
		player: int, slot: int) -> int:
	if not ActionDef.is_attack(action):
		return dmg
	var lost_health: int = maxi(
		int(battle.max_hp[player][slot]) - int(battle.hp[player][slot]), 0)
	var bonus_steps: int = floori(
		float(lost_health) / float(LOST_HEALTH_PER_BONUS))
	return dmg + bonus_steps * DAMAGE_PER_BONUS
