extends HeroSkill

## h09 紫火【六爪阎罗】被动 · 干扰
## 攻击命中敌方出战造成伤害时，震碎对手等量能量（蒸发、不入己方池）：
## 波(1.0HP=2半)→碎1能(2半能)、大波(2.0HP=4半)→碎2能。受 0 = 不碎。

func on_deal_hit(battle: BattleCore, player: int, _slot: int, target_player: int, _target_slot: int, dealt: int, _action: int) -> void:
	if dealt <= 0:
		return
	battle.energy[target_player] = maxi(0, battle.energy[target_player] - dealt)
