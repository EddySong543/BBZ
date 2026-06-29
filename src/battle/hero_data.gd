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
@export var role: String = ""
@export var position: String = ""
@export var portrait_path: String = ""
@export var skill_icon_path: String = ""  ## 技能图标（符号徽记·res://...png）；空或不存在则不显示。
@export var spritesheet_path: String = ""
@export var sprite_frames_path: String = ""
@export var attack_spritesheet_path: String = ""
@export var hit_spritesheet_path: String = ""
@export var defend_spritesheet_path: String = ""
@export var defeat_spritesheet_path: String = ""

const HEROES_DIR := "res://assets/data/heroes/"


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


## 首发英雄池：12 生肖 + 黑暗全 12（虚日…室火·h01-h24）。将来扩张改这里的数字。
## ⚠ 改池大小须同步 bp_screen.gd 的 ROWS 网格行配置（否则末排英雄不显示）。
static func create_launch_pool(heroes_dir: String = HEROES_DIR) -> Array[HeroData]:
	return create_pool_heroes(heroes_dir).slice(0, 24)
