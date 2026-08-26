extends RefCounted
class_name EffectCatalog

## 玩家可见的通用战斗效果目录。
## 名称、解释与语义色集中在这里，图鉴和后续战斗内提示共用同一份真相源。

const EFFECTS: Array[Dictionary] = [
	{
		"id": &"bonus_effect",
		"name": "附加效果",
		"icon_path": "res://assets/ui/effects/bonus_effect.png",
		"description": "一次攻击除了造成伤害，还额外触发的效果。额外触发只重复英雄技能；道具附带效果每次攻击最多结算一次。",
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
		"description": "可叠加。中毒英雄再次被「波」或「大波」命中时，引爆并清除全部毒素，每层造成 0.5 点伤害。",
		"ink": Color("214B36"),
		"accent": Color("5A9470"),
		"edge": Color("163424"),
	},
	{
		"id": &"vulnerable",
		"name": "脆弱",
		"icon_path": "res://assets/ui/effects/vulnerable.png",
		"description": "受到的伤害增加 0.5 点。",
		"ink": Color("6A3030"),
		"accent": Color("B15F58"),
		"edge": Color("451F1F"),
	},
	{
		"id": &"sword_qi",
		"name": "剑气",
		"icon_path": "res://assets/ui/effects/sword_qi.png",
		"description": "最多积累4点。昴日【鸡】发动「太初万法剑」时消耗全部剑气，每点增加0.5点伤害；2点穿防，4点穿大防。",
		"ink": Color("24464B"),
		"accent": Color("5F8C8F"),
		"edge": Color("172D30"),
	},
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
