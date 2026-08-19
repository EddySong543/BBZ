extends HeroSkill

## h23 天狗【天光长蚀】被动 · 资源压制 · HP6
## 自身「波 / 大波」实际落血多少，就等量降低目标所属队伍的能量上限，最低 3 点。
## 合并进该次攻击伤害的道具加成计入；道具另行造成的独立伤害不计入。
## 已经超过新上限的现有能量保留；在能量降到上限以下前，所有后续得能均为 0。
## 本技能走一次性 on_base_attack_damage_dealt，不随双生咒符等额外 on-hit 重复，
## 也不响应主动技、追击、反击或溅射伤害。

const MIN_ENERGY_MAX := 3 * ActionDef.ENERGY_UNIT


func on_base_attack_damage_dealt(battle: BattleCore, _player: int, _slot: int,
		target_player: int, target_slot: int, dealt: int, _action: int, events: Array) -> void:
	if dealt <= 0:
		return
	var reduced: int = battle.reduce_energy_max(target_player, dealt, MIN_ENERGY_MAX)
	if reduced <= 0:
		return
	events.append({
		id = "energy_max_reduced",
		player = target_player,
		slot = target_slot,
		amount = reduced,
		new_max = battle.energy_max[target_player],
	})
