extends HeroSkill

## h30 星星【北辰守望】被动 · 团队层（后排参战）
## 星星在替补席存活时，出战队友每次受伤由星星分担一半（队友与星星各承一半）。
## 星星上场或阵亡则失效。半点对半：奇数半点时星星取 floor、队友取剩余（守恒、落 0.5 档）。
## 机制本质=伤害再分配（非减伤），总伤不变。

func on_ally_take_damage(dmg: int, _ally_slot: int, battle: BattleCore, player: int, slot: int) -> int:
	# 仅当本英雄（星星）在替补席且存活时分担
	if slot == battle.active_index[player] or battle.hp[player][slot] <= 0 or dmg <= 0:
		return dmg
	var share: int = dmg / 2   # 星星承担一半（整数半点；dmg=1 半点时 share=0 不分担）
	if share <= 0:
		return dmg
	battle.hp[player][slot] -= share
	return dmg - share
