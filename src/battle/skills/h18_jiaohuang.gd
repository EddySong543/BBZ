extends HeroSkill

## h18 教皇【万民归心】被动 · 单英雄（强度由团队存活驱动）
## 教皇出战承伤时，每有 1 名存活队友 -0.5 受伤（2 队友 = 最多 -1.0，最低 0）。
## 0.5 = 1 半点（首个半血实战机制）。前期满编近免疫、后期变弱。

func modify_incoming_damage(dmg: int, _action: int, battle: BattleCore, player: int, _slot: int, _attacker_player: int) -> int:
	var allies: int = battle.living_reserves(player).size()   # 存活替补数（0~2）
	return maxi(dmg - allies, 0)   # -1 半点(0.5) / 队友
