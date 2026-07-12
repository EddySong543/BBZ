extends RefCounted

## 故事模式通关进度（任务 B 壳·2026-07-12）：内存态 + user:// 持久化。
## 纯逻辑无场景依赖；核心判定（通关/解锁）不碰文件系统 → GUT 单测零外部状态。
## 使用方经 preload 引用（headless class_name 注册坑）。
##
## 用法：
##   const StoryProgress := preload("res://src/story/story_progress.gd")
##   var pg := StoryProgress.new()
##   pg.load_from_disk()
##   if pg.is_unlocked(level): ...
##   pg.mark_cleared("main_01"); pg.save_to_disk()

const SAVE_PATH := "user://story_progress.cfg"
const _SECTION := "cleared"

var _cleared: Dictionary = {}   # level_id -> true


## 标记通关（幂等）。
func mark_cleared(level_id: String) -> void:
	if not level_id.is_empty():
		_cleared[level_id] = true


func is_cleared(level_id: String) -> bool:
	return _cleared.has(level_id)


func cleared_count() -> int:
	return _cleared.size()


## 关卡是否解锁：requires 为空 = 直接可打；否则前置关须已通关。
func is_unlocked(level: Dictionary) -> bool:
	var req: String = String(level.get("requires", ""))
	return req.is_empty() or is_cleared(req)


## 持久化（ConfigFile·失败仅告警不炸——壳期进度丢失可接受）。
func save_to_disk(path: String = SAVE_PATH) -> void:
	var cf := ConfigFile.new()
	for id in _cleared:
		cf.set_value(_SECTION, String(id), true)
	var err := cf.save(path)
	if err != OK:
		push_warning("StoryProgress: 进度保存失败 %s (err=%d)" % [path, err])


## 读档（文件不存在=全新进度·静默）。
func load_from_disk(path: String = SAVE_PATH) -> void:
	_cleared = {}
	var cf := ConfigFile.new()
	if cf.load(path) != OK or not cf.has_section(_SECTION):
		return
	for key in cf.get_section_keys(_SECTION):
		if bool(cf.get_value(_SECTION, key, false)):
			_cleared[String(key)] = true
