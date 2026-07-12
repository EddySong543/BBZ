extends RefCounted

## 故事模式关卡目录（任务 B 壳·2026-07-12）：加载并校验 assets/data/story/levels.json。
## 纯逻辑无场景依赖（GUT 可 headless 测）；使用方经 preload 引用（headless class_name 注册坑·
## 见记忆 godot-headless-classname-preload）。关卡内容=数据驱动，代码零硬编码关卡。
##
## 用法：
##   const StoryCatalog := preload("res://src/story/story_catalog.gd")
##   var levels: Array = StoryCatalog.load_levels()
##   var cols: Dictionary = StoryCatalog.by_category(levels)   # "main" -> [level, ...]（按 order 升序）

const LEVELS_PATH := "res://assets/data/story/levels.json"
const CATEGORIES: Array[String] = ["main", "hero", "group", "casual"]   # 展示顺序即此序
const CATEGORY_NAMES := {main = "主线", hero = "个人", group = "群像", casual = "休闲"}
const TEAM_SIZE := 3   # 与 BP/battle_screen 标准阵容一致


## 加载关卡表。文件缺失/解析失败返回空数组并 push_warning（壳期不炸屏·选关屏显示为空列表）。
static func load_levels(path: String = LEVELS_PATH) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("StoryCatalog: 关卡表不存在 %s" % path)
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null or not (data is Dictionary) or not (data.get("levels") is Array):
		push_warning("StoryCatalog: 关卡表解析失败 %s" % path)
		return []
	return data["levels"]


## 按类别分组，组内按 order 升序。类别键固定为 CATEGORIES 全集（空类别=空数组·选关屏照常出列）。
static func by_category(levels: Array) -> Dictionary:
	var out: Dictionary = {}
	for c in CATEGORIES:
		out[c] = []
	for lv in levels:
		var c: String = String(lv.get("category", ""))
		if out.has(c):
			out[c].append(lv)
	for c in CATEGORIES:
		out[c].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 0)) < int(b.get("order", 0)))
	return out


## 按 id 找关卡。找不到返回空字典。
static func find_level(levels: Array, id: String) -> Dictionary:
	for lv in levels:
		if String(lv.get("id", "")) == id:
			return lv
	return {}


## 结构校验（测试锁数据质量·选关屏不调用）。返回错误清单，空=通过。
static func validate(levels: Array) -> Array[String]:
	var errs: Array[String] = []
	var seen_ids: Dictionary = {}
	for lv in levels:
		var id: String = String(lv.get("id", ""))
		if id.is_empty():
			errs.append("存在空 id 关卡")
			continue
		if seen_ids.has(id):
			errs.append("%s: id 重复" % id)
		seen_ids[id] = true
		if not CATEGORIES.has(String(lv.get("category", ""))):
			errs.append("%s: 非法类别 %s" % [id, lv.get("category")])
		if String(lv.get("title", "")).is_empty():
			errs.append("%s: 标题为空" % id)
		if not (lv.get("intro_lines") is Array) or (lv["intro_lines"] as Array).is_empty():
			errs.append("%s: 简介文本为空" % id)
		for key in ["player_team", "enemy_team"]:
			var team: Variant = lv.get(key)
			if not (team is Array) or (team as Array).size() != TEAM_SIZE:
				errs.append("%s: %s 须为 %d 人" % [id, key, TEAM_SIZE])
		if int(lv.get("order", 0)) <= 0:
			errs.append("%s: order 须为正整数" % id)
	for lv in levels:
		var req: String = String(lv.get("requires", ""))
		if not req.is_empty() and not seen_ids.has(req):
			errs.append("%s: requires 指向不存在的关卡 %s" % [lv.get("id"), req])
	return errs
