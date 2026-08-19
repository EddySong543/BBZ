extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	var opponent: int = 1 - player
	if battle.item_debuff_blocked(opponent):
		return
	battle.set_item_mod(opponent, "hit_hero_skills_suppressed", true)
