extends RefCounted
class_name EffectCatalog

## 玩家可见的通用战斗效果目录。
## 名称、解释与语义色集中在这里，图鉴和后续战斗内提示共用同一份真相源。

const EFFECTS: Array[Dictionary] = [
	{
		"id": &"bonus_effect",
		"name": "附加效果",
		"icon_path": "res://assets/ui/effects/bonus_effect.png",
		"description": "像毒素，剑气等都属于附加效果。附加效果只会被「波」或「大波」命中触发，道具无法触发。",
		"ink": Color("5D3E1F"),
		"accent": Color("A8783C"),
		"edge": Color("3D2714"),
	},
	{
		"id": &"true_damage",
		"name": "真实伤害",
		"icon_path": "res://assets/ui/effects/true_damage.png",
		"description": "无视防御和护甲的伤害。",
		"ink": Color("49345F"),
		"accent": Color("8066A3"),
		"edge": Color("2D203B"),
	},
	{
		"id": &"h02_wave_upgrade",
		"name": "玄金不动相",
		"icon_path": "res://assets/sprites/heroes/h02/h02_skill.png",
		"description": "我方下一次的波升级为大波。",
		"show_stack_count": false,
		"ink": Color("55421C"),
		"accent": Color("B99A52"),
		"edge": Color("392C13"),
	},
	{
		"id": &"h08_retained_big_defend",
		"name": "不坠神言",
		"icon_path": "res://assets/sprites/heroes/h08/h08_skill.png",
		"description": "大防直到下回合结束。",
		"show_stack_count": false,
		"ink": Color("38475B"),
		"accent": Color("788BA5"),
		"edge": Color("252F3D"),
	},
	{
		"id": &"pierce_defense",
		"name": "穿防",
		"icon_path": "res://assets/ui/effects/pierce_defense.png",
		"description": "攻击穿透「防」。",
		"ink": Color("2B4A5C"),
		"accent": Color("5F8394"),
		"edge": Color("1B303B"),
	},
	{
		"id": &"pierce_guard",
		"name": "穿大防",
		"icon_path": "res://assets/ui/effects/pierce_guard.png",
		"description": "攻击穿透「大防」。",
		"ink": Color("233B66"),
		"accent": Color("536F9D"),
		"edge": Color("172742"),
	},
	{
		"id": &"armor",
		"name": "护甲",
		"icon_path": "res://assets/ui/effects/armor.png",
		"description": "额外生命层，先扣护甲后扣生命；真实伤害无视护甲。",
		"ink": Color("20485F"),
		"accent": Color("4D7890"),
		"edge": Color("142E3D"),
	},
	{
		"id": &"poison",
		"name": "毒素",
		"icon_path": "res://assets/ui/effects/poison.png",
		"description": "可叠加。中毒英雄被「大波」命中时，引爆并清除全部毒素，每层造成 0.5 点伤害。",
		"show_stack_count": true,
		"ink": Color("214B36"),
		"accent": Color("5A9470"),
		"edge": Color("163424"),
	},
	{
		"id": &"vulnerable",
		"name": "脆弱",
		"icon_path": "res://assets/ui/effects/vulnerable.png",
		"description": "受到的伤害增加 0.5 点。",
		"show_stack_count": true,
		"ink": Color("6A3030"),
		"accent": Color("B15F58"),
		"edge": Color("451F1F"),
	},
	{
		"id": &"sword_qi",
		"name": "剑气",
		"icon_path": "res://assets/ui/effects/sword_qi.png",
		"description": "最多积累4点，昴日【鸡】发动「飞洒天星」时消耗全部剑气。",
		"show_stack_count": true,
		"ink": Color("24464B"),
		"accent": Color("5F8C8F"),
		"edge": Color("172D30"),
	},
]

## 英雄槽位状态与队伍状态分开映射；UI 只消费标准化条目，不推断机制归属。
const HERO_STATUS_EFFECTS: Array[Dictionary] = [
	{"status_key": "poison", "effect_id": &"poison"},
	{"status_key": "vuln", "effect_id": &"vulnerable"},
]
const TEAM_STATUS_EFFECTS: Array[Dictionary] = [
	{"status_key": "jianqi", "effect_id": &"sword_qi"},
	{"status_key": "upgrade_next_wave", "effect_id": &"h02_wave_upgrade"},
	{"status_key": "retained_big_defend", "effect_id": &"h08_retained_big_defend"},
]


static func all() -> Array[Dictionary]:
	return EFFECTS.duplicate(true)


static func get_by_id(effect_id: StringName) -> Dictionary:
	for entry: Dictionary in EFFECTS:
		if entry.id == effect_id:
			return entry.duplicate(true)
	return {}


static func index_of(effect_id: StringName) -> int:
	for index: int in EFFECTS.size():
		if EFFECTS[index].id == effect_id:
			return index
	return -1


static func battle_status_entries(hero_status_values: Dictionary,
		team_status_values: Dictionary = {}, hero_slot: int = -1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_append_status_entries(entries, HERO_STATUS_EFFECTS, hero_status_values,
			"hero:%d" % hero_slot)
	_append_status_entries(entries, TEAM_STATUS_EFFECTS, team_status_values, "team")
	return entries


static func _append_status_entries(entries: Array[Dictionary], mappings: Array[Dictionary],
		status_values: Dictionary, scope_key: String) -> void:
	for mapping: Dictionary in mappings:
		var status_key := String(mapping.status_key)
		var raw_value: Variant = status_values.get(status_key, 0)
		var value := int(raw_value) if raw_value is int or raw_value is float else (
				1 if bool(raw_value) else 0)
		if value <= 0:
			continue
		var entry := get_by_id(StringName(mapping.effect_id))
		if entry.is_empty():
			continue
		entry["status_key"] = status_key
		entry["value"] = value
		entry["scope"] = scope_key.get_slice(":", 0)
		entry["instance_key"] = "%s:%s" % [scope_key, status_key]
		entries.append(entry)
