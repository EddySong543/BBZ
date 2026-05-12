class_name HeroData
extends Resource

## Hero definition — data only, logic lives in BattleCore.

enum SkillType { PASSIVE, EXTRA_ACTION, ENHANCED_ACTION }

@export var hero_id: String = ""
@export var hero_name: String = ""
@export var max_hp: int = 10
@export var skill_type: int = SkillType.PASSIVE
@export var skill_description: String = ""
@export var extra_action_id: int = -1
@export var passive_id: String = ""
@export var role: String = ""
@export var position: String = ""
@export var action_overrides: Dictionary = {}


func has_skill_type(t: int) -> bool:
	return skill_type == t


func get_override(action: int, key: String):
	if action_overrides.has(action) and action_overrides[action].has(key):
		return action_overrides[action][key]
	return null


func get_cost_override(action: int, default_cost: int) -> int:
	var v = get_override(action, "cost")
	return v if v != null else default_cost


func get_damage_override(action: int, default_damage: int) -> int:
	var v = get_override(action, "damage")
	return v if v != null else default_damage


# --- 46-hero pool (placeholder — user will replace with real designs) ---

static func create_pool_heroes() -> Array[HeroData]:
	var pool: Array[HeroData] = []
	var heroes_def: Array[Dictionary] = _hero_defs()
	for d in heroes_def:
		var h := HeroData.new()
		h.hero_id = d.get("id", "")
		h.hero_name = d.get("name", "")
		h.max_hp = d.get("hp", 10)
		h.skill_type = d.get("skill_type", SkillType.PASSIVE)
		h.skill_description = d.get("desc", "（待设计）")
		h.role = d.get("role", "通用")
		h.position = d.get("position", "灵活")
		h.passive_id = d.get("passive_id", "")
		h.extra_action_id = d.get("extra_action", -1)
		pool.append(h)
	return pool


static func _hero_defs() -> Array[Dictionary]:
	return [
		{id="h01", name="子鼠", hp=8,  role="经济型", position="首发",   skill_type=SkillType.PASSIVE, passive_id="zishu", desc="双方同时出「攒」时，你额外获得1点能量"},
		{id="h02", name="丑牛", hp=11, role="防御型", position="中核",   skill_type=SkillType.EXTRA_ACTION, extra_action=6, desc="【金角】消耗2能。本回合若受伤害，对对手造成等量伤害"},
		{id="h03", name="寅虎", hp=9,  role="爆发型", position="后期",   skill_type=SkillType.EXTRA_ACTION, extra_action=7, desc="【虎袭】消耗全部能量(上限6)，造成等量次数的1点伤害，可被大防格挡"},
		{id="h04", name="卯兔", hp=8,  role="防御型", position="轮转",   skill_type=SkillType.EXTRA_ACTION, extra_action=8, desc="【狡兔三窟】消耗1能。本回合免疫伤害，下回合随机切换英雄，本回合无法获能"},
		{id="h05", name="辰龙", hp=10, role="爆发型", position="后期",   skill_type=SkillType.PASSIVE, passive_id="chenlong", desc="【龙威】每比对手多2点能量，攻击伤害+1"},
		{id="h06", name="巳蛇", hp=10, role="反制型", position="中核",   skill_type=SkillType.EXTRA_ACTION, extra_action=9, desc="【蛇蜕】消耗1能。本回合若死亡，复活并拥有1HP和1能量"},
		{id="h07", name="午马", hp=12, role="经济型", position="轮转",   skill_type=SkillType.PASSIVE, passive_id="wuma", desc="切换上场时获得1护盾；切换下场时，下个登场英雄获得1护盾"},
		{id="h08", name="未羊", hp=12, role="经济型", position="中核",   skill_type=SkillType.EXTRA_ACTION, extra_action=10, desc="【献祭】消耗2HP，获得3能量"},
		{id="h09", name="申猴", hp=8,  role="赌博型", position="中核",   skill_type=SkillType.EXTRA_ACTION, extra_action=11, desc="【身外化身】消耗3能，创建2个假身(1HP)；对手需选择攻击目标，真假位置随机打乱"},
		{id="h10", name="酉鸡", hp=10, role="进攻型", position="中核",   skill_type=SkillType.PASSIVE, passive_id="sichen", desc="【司晨】第3/6/9...回合，波自动升级为大波"},
		{id="h11", name="戌狗", hp=7,  role="爆发型", position="后期",   skill_type=SkillType.PASSIVE, passive_id="xugou", desc="【认主】每当一名队友死亡，本英雄技能获得：波伤害+1，防护盾值+1"},
		{id="h12", name="亥猪", hp=12, role="经济型", position="首发",   skill_type=SkillType.PASSIVE, passive_id="haizhu", desc="【纳福】受到伤害后，获得等同于伤害的能量"},
		{id="h13", name="金刚", hp=13, role="防御型", position="先锋",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h14", name="飞燕", hp=9,  role="进攻型", position="首发",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h15", name="玄龟", hp=12, role="防御型", position="后手",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h16", name="猎手", hp=9,  role="进攻型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h17", name="鬼面", hp=10, role="骗招型", position="灵活",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h18", name="雷霆", hp=10, role="爆发型", position="终结",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h19", name="寒冰", hp=11, role="反制型", position="后手",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h20", name="赤炎", hp=9,  role="爆发型", position="终结",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h21", name="铁拳", hp=11, role="进攻型", position="先锋",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h22", name="灵狐", hp=8,  role="骗招型", position="灵活",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h23", name="山岭", hp=13, role="防御型", position="先锋",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h24", name="疾风", hp=10, role="切换型", position="轮转",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h25", name="黑曜", hp=12, role="防御型", position="后手",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h26", name="血月", hp=8,  role="赌博型", position="终结",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h27", name="翠蛇", hp=9,  role="反制型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h28", name="钢骨", hp=12, role="防御型", position="先锋",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h29", name="幻影", hp=9,  role="骗招型", position="灵活",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h30", name="熔岩", hp=10, role="爆发型", position="终结",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h31", name="霜刃", hp=9,  role="进攻型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h32", name="残影", hp=8,  role="切换型", position="轮转",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h33", name="巨鳄", hp=12, role="防御型", position="先锋",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h34", name="枭鹰", hp=9,  role="反制型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h35", name="炎龙", hp=10, role="爆发型", position="终结",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h36", name="霜狼", hp=10, role="进攻型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h37", name="金钟", hp=11, role="防御型", position="轮转",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h38", name="幽魂", hp=8,  role="赌博型", position="灵活",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h39", name="裂天", hp=10, role="爆发型", position="终结",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h40", name="地藏", hp=11, role="经济型", position="后手",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h41", name="追光", hp=9,  role="切换型", position="轮转",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h42", name="破晓", hp=10, role="进攻型", position="首发",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h43", name="潮汐", hp=10, role="蓄势型", position="后手",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h44", name="鸣雷", hp=9,  role="赌博型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h45", name="苍炎", hp=10, role="进攻型", position="中核",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
		{id="h46", name="不灭", hp=11, role="蓄势型", position="后手",   skill_type=SkillType.PASSIVE, desc="（待设计）"},
	]


static func create_mvp_heroes() -> Array[HeroData]:
	return create_pool_heroes().slice(0, 8)
