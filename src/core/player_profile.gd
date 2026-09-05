class_name PlayerProfile
extends RefCounted

## 玩家个人资料 —— 全静态类（GameSettings 同范式·无需 autoload，避免改 project.godot）。
##
## 持久化到 user://player_profile.cfg（Godot ConfigFile）。
## 身份：player_name（改名走 set_player_name·截 8 字）/ avatar_hero（头像=英雄 id·h01-h24）/
##       created_ts（建档 unix 秒·首次落盘时盖章）。
## 远征进度与战斗结果由各自系统管理，不把已移除的对战统计写进身份档案。
## UI（主菜单身份带 / profile_screen）只经此类读写，不自持状态（ui-code 规）。

const _PATH := "user://player_profile.cfg"
const _SEC_ID := "identity"

const NAME_MAX_CHARS := 8
const DEFAULT_NAME := "无名"
const DEFAULT_AVATAR := "h01"

## 测试/探针关闭落盘用（内存态照常工作·GUT 单测禁碰文件系统）。
static var save_enabled: bool = true

static var _data: Dictionary = {}
static var _loaded: bool = false


# ============================================================
# 身份
# ============================================================

static func get_player_name() -> String:
	_ensure_loaded()
	return String(_data["player_name"])


## 改名：去首尾空白 + 截 NAME_MAX_CHARS 字；空串忽略（保留旧名）。
static func set_player_name(n: String) -> void:
	_ensure_loaded()
	var trimmed := n.strip_edges()
	if trimmed.is_empty():
		return
	_data["player_name"] = trimmed.substr(0, NAME_MAX_CHARS)
	_save()


static func get_avatar_hero() -> String:
	_ensure_loaded()
	return String(_data["avatar_hero"])


static func set_avatar_hero(hero_id: String) -> void:
	if hero_id.is_empty():
		return
	_ensure_loaded()
	_data["avatar_hero"] = hero_id
	_save()


## 头像立绘路径（英雄目录统一命名）；资源缺失回落默认英雄（防坏档指向空图）。
static func avatar_portrait_path() -> String:
	var p := _portrait_of(get_avatar_hero())
	if ResourceLoader.exists(p):
		return p
	return _portrait_of(DEFAULT_AVATAR)


static func _portrait_of(hero_id: String) -> String:
	return "res://assets/sprites/heroes/%s/%s_portrait.png" % [hero_id, hero_id]


## 建档日期文本（"2026-07-16"）；尚未落过盘 = "—"。
static func created_text() -> String:
	_ensure_loaded()
	var ts := int(_data["created_ts"])
	if ts <= 0:
		return "—"
	var d := Time.get_datetime_dict_from_unix_time(ts)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


# ============================================================
# 持久化
# ============================================================

static func _defaults() -> Dictionary:
	var d := {
		"player_name": DEFAULT_NAME,
		"avatar_hero": DEFAULT_AVATAR,
		"created_ts": 0,
	}
	return d


static func _ensure_loaded() -> void:
	if not _loaded:
		load_from_disk()


static func load_from_disk() -> void:
	_data = _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(_PATH) == OK:
		for k: String in ["player_name", "avatar_hero", "created_ts"]:
			if cfg.has_section_key(_SEC_ID, k):
				var raw: Variant = cfg.get_value(_SEC_ID, k, _data[k])
				# 类型门（2026-07-17 终审修复）：手改/坏盘的异常类型回默认（防下游 String()/int() 炸）
				if (k == "created_ts" and (raw is int or raw is float)) \
						or (k != "created_ts" and raw is String):
					_data[k] = raw
	_loaded = true
	# 首次建档：盖建档时间戳并落盘（生成存档文件）。
	if int(_data["created_ts"]) <= 0 and save_enabled:
		_data["created_ts"] = int(Time.get_unix_time_from_system())
		_save()


static func _save() -> void:
	if not save_enabled:
		return
	if int(_data.get("created_ts", 0)) <= 0:
		_data["created_ts"] = int(Time.get_unix_time_from_system())
	var cfg := ConfigFile.new()
	for k: String in ["player_name", "avatar_hero", "created_ts"]:
		cfg.set_value(_SEC_ID, k, _data[k])
	if cfg.save(_PATH) != OK:
		push_warning("PlayerProfile: 资料保存失败（%s·磁盘只读/占用?）——本次改动仅内存生效" % _PATH)   # 终审修复：保存失败不再静默


## 重置为默认（测试/探针·或将来"重置资料"入口）。save_enabled 关闭时纯内存。
static func reset() -> void:
	_data = _defaults()
	_loaded = true
	_save()
