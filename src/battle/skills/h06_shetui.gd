extends HeroSkill

## h06 巳蛇【蛇蜕】被动 · 单英雄
## 本局首次受致死伤时不死 → 重生为 2 HP + 清除自身全部 debuff，每局 1 次。
## debuff 清单随后续英雄扩充（燃烧 h32 / 易伤 / 沉默 h15 等）。

const REVIVE_HP_HALF := 2 * ActionDef.HP_UNIT   # 2.0 HP
const DEBUFF_KEYS := ["burn", "vulnerable", "silenced_until"]


func on_before_death(battle: BattleCore, player: int, slot: int) -> bool:
	if battle.get_status(player, slot, "shetui_used", false):
		return false   # 已用过，正常死亡
	battle.set_status(player, slot, "shetui_used", true)
	battle.hp[player][slot] = REVIVE_HP_HALF
	for key in DEBUFF_KEYS:
		battle.statuses[player][slot].erase(key)
	return true   # 存活
