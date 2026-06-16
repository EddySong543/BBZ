class_name HeroData
extends Resource

## Hero definition — data only, logic lives in BattleCore.
## 数据源：assets/data/heroes/*.tres（一个英雄一个文件，editor 可直改）。

enum SkillType { PASSIVE, EXTRA_ACTION, ENHANCED_ACTION }

@export var hero_id: String = ""
@export var hero_name: String = ""
@export var max_hp: int = 10
@export var skill_type: int = SkillType.PASSIVE
@export var skill_description: String = ""  ## 技能名（短，如「渴血」）；展示格标题用。
@export var skill_detail: String = ""       ## 技能完整说明（展示格正文用）；为空则回退 skill_description。
@export var extra_action_id: int = -1
@export var passive_id: String = ""
@export var role: String = ""
@export var position: String = ""
@export var action_overrides: Dictionary = {}
@export var portrait_path: String = ""
@export var spritesheet_path: String = ""
@export var sprite_frames_path: String = ""
@export var attack_spritesheet_path: String = ""
@export var hit_spritesheet_path: String = ""
@export var defend_spritesheet_path: String = ""
@export var defeat_spritesheet_path: String = ""

const HEROES_DIR := "res://assets/data/heroes/"


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


static func get_portrait_path(hero_id: String) -> String:
	return "res://assets/sprites/heroes/%s/%s_portrait.png" % [hero_id, hero_id]


static func get_spritesheet_path(hero_id: String) -> String:
	return "res://assets/sprites/heroes/%s/%s_spritesheet.png" % [hero_id, hero_id]


## 从 assets/data/heroes/*.tres 加载所有英雄。
## 按文件名字典序排序（h01 < h02 < ... < h13），保证稳定顺序。
static func create_pool_heroes(heroes_dir: String = HEROES_DIR) -> Array[HeroData]:
	var pool: Array[HeroData] = []
	var dir := DirAccess.open(heroes_dir)
	if dir == null:
		push_error("HeroData: 无法打开目录 %s" % heroes_dir)
		return pool

	var filenames: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			filenames.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	filenames.sort()

	for f in filenames:
		var path := heroes_dir + f
		var res: Resource = load(path)
		if res is HeroData:
			pool.append(res)
		else:
			push_warning("HeroData: 跳过非 HeroData 资源 %s" % path)
	return pool


## 首发英雄池：只前 12 生肖（h13+ 暂隐藏）。将来扩张到 18 / 24 改这里的 12。
static func create_launch_pool(heroes_dir: String = HEROES_DIR) -> Array[HeroData]:
	return create_pool_heroes(heroes_dir).slice(0, 12)


static func create_mvp_heroes() -> Array[HeroData]:
	return create_pool_heroes().slice(0, 8)
