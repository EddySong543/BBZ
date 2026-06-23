class_name GameSettings
extends RefCounted

## 全局游戏设置 —— 全静态类，无需 autoload（避免改 project.godot）。
##
## 持久化到 user://bobozan_settings.cfg（Godot ConfigFile）。
## 启动时由 boot_screen._ready() 调一次 load_and_apply()；
## 设置面板（settings_panel.gd）每次改动调 set_value() → 即时应用 + 落盘。
##
## 覆盖的游戏相关设置：
##   - master_volume / music_volume / sfx_volume：音量（接 AudioServer 总线，
##     Music/SFX 总线尚未建[无音频内容期]→值仍持久化、等音频接入即生效）。
##   - fullscreen：全屏 / 窗口。
##   - invert_colors：界面主色 红↔蓝 翻转（写入 BootResult，过场幕 + 菜单/BP 波流背景全链路生效）。

const _PATH := "user://bobozan_settings.cfg"
const _SECTION := "game"

## 默认值（同时也是合法键的白名单）。
const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"invert_colors": false,
}

static var _data: Dictionary = {}
static var _loaded: bool = false


# ============================================================
# 读 / 写
# ============================================================

static func get_value(key: String) -> Variant:
	if not _loaded:
		load_from_disk()
	return _data.get(key, DEFAULTS.get(key))


## 改一个设置：写内存 → 即时应用 → 落盘。
static func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("GameSettings: 未知设置键 '%s'" % key)
		return
	if not _loaded:
		load_from_disk()
	_data[key] = value
	_apply_one(key)
	save()


static func reset_defaults() -> void:
	_data = DEFAULTS.duplicate(true)
	_loaded = true
	apply_all()
	save()


# ============================================================
# 持久化
# ============================================================

static func load_from_disk() -> void:
	_data = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(_PATH) == OK:
		for k: String in DEFAULTS.keys():
			if cfg.has_section_key(_SECTION, k):
				_data[k] = cfg.get_value(_SECTION, k, DEFAULTS[k])
	_loaded = true


static func save() -> void:
	var cfg := ConfigFile.new()
	for k: String in _data.keys():
		cfg.set_value(_SECTION, k, _data[k])
	cfg.save(_PATH)


# ============================================================
# 应用
# ============================================================

## 启动时调用：加载 + 应用全部设置。
static func load_and_apply() -> void:
	load_from_disk()
	apply_all()


static func apply_all() -> void:
	for k: String in DEFAULTS.keys():
		_apply_one(k)


static func _apply_one(key: String) -> void:
	match key:
		"master_volume":
			_apply_bus_volume("Master", float(get_value("master_volume")))
		"music_volume":
			_apply_bus_volume("Music", float(get_value("music_volume")))
		"sfx_volume":
			_apply_bus_volume("SFX", float(get_value("sfx_volume")))
		"fullscreen":
			_apply_fullscreen(bool(get_value("fullscreen")))
		"invert_colors":
			BootResult.invert_colors = bool(get_value("invert_colors"))


## 设音量总线。Music/SFX 总线尚未建时静默跳过（值已持久化，等音频接入即生效）。
static func _apply_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.0)
	if v > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))


static func _apply_fullscreen(on: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
