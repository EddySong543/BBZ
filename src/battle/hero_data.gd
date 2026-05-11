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


# --- Placeholder heroes (user will redesign) ---

static func create_hero_a() -> HeroData:
	var h := HeroData.new()
	h.hero_id = "hero_a"
	h.hero_name = "英雄A"
	h.max_hp = 10
	h.skill_type = SkillType.PASSIVE
	h.skill_description = "（待设计）"
	h.role = "通用"
	h.position = "灵活"
	return h


static func create_hero_b() -> HeroData:
	var h := HeroData.new()
	h.hero_id = "hero_b"
	h.hero_name = "英雄B"
	h.max_hp = 10
	h.skill_type = SkillType.PASSIVE
	h.skill_description = "（待设计）"
	h.role = "通用"
	h.position = "灵活"
	return h


static func create_mvp_heroes() -> Array[HeroData]:
	return [create_hero_a(), create_hero_b()]
