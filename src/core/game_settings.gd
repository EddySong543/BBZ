class_name GameSettings
extends RefCounted

## 全局游戏设置 —— 全静态类，无需 autoload（避免改 project.godot）。
##
## 持久化到 user://bobozan_settings.cfg（Godot ConfigFile）。
## 启动时由 boot_screen._ready() 调一次 load_and_apply()；
## 设置面板（settings_panel.gd）每次改动调 set_value() → 即时应用 + 落盘。
##
## 覆盖的游戏相关设置：
##   - master_volume / music_volume / sfx_volume：音量（接 AudioServer 总线；
##     Music/SFX 总线由 AudioEvents.ensure_buses() 运行时建——boot 启动即建·
##     建完回调 apply_volumes() 回灌持久化值）。
##   - window_mode：显示模式 windowed(窗口化) / borderless(全屏窗口化) / fullscreen(独占全屏)。
##     （2026-07-09 取代旧 fullscreen 布尔键·旧 cfg 自动迁移）
##   - resolution："宽x高" 字符串，仅窗口化模式生效（全屏两档跟随屏幕）。
##     设计画布恒 1920×1080，窗口尺寸变化由 content_scale 等比缩放（工程未配 stretch·运行时接管）。
##   - invert_colors：界面主色 红↔蓝 翻转（写入 BootResult，过场幕 + 菜单/BP 波流背景全链路生效）。

const _PATH := "user://bobozan_settings.cfg"
const _SECTION := "game"

## 设计画布（所有 UI 按此布局·窗口另有尺寸时 content_scale 等比缩放）。
const DESIGN_SIZE := Vector2i(1920, 1080)

## 窗口化模式可选分辨率（16:9·设置面板按屏幕大小过滤展示）。
const RESOLUTION_PRESETS: Array[String] = ["1280x720", "1600x900", "1920x1080", "2560x1440"]

## 默认值（同时也是合法键的白名单）。
const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"window_mode": "windowed",
	"resolution": "1920x1080",
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
	_data[key] = sanitize(key, value)   # 代码路径同过规范化门（终审修复·与读盘同一收口）
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
				_data[k] = sanitize(k, cfg.get_value(_SECTION, k, DEFAULTS[k]))
		# 旧键迁移：fullscreen(bool) → window_mode（2026-07-09 显示设置改版）
		if cfg.has_section_key(_SECTION, "fullscreen") and not cfg.has_section_key(_SECTION, "window_mode"):
			_data["window_mode"] = "borderless" if bool(cfg.get_value(_SECTION, "fullscreen", false)) else "windowed"
	_loaded = true


## 配置项规范化（2026-07-17 终审修复）：语法合法但类型/数值异常的配置（音量="LOUD"/-1000·
## 分辨率=999999999x999999999·布尔=数组→ bool() 构造脚本错误）落进类型门+钳制+枚举白名单，
## 异常值静默回默认——手改 cfg/坏盘不再能在启动时炸脚本或开天价窗口。
static func sanitize(key: String, v: Variant) -> Variant:
	match key:
		"master_volume", "music_volume", "sfx_volume":
			if v is float or v is int:
				return clampf(float(v), 0.0, 1.0)
		"window_mode":
			if v is String and String(v) in ["windowed", "borderless", "fullscreen"]:
				return v
		"resolution":
			if v is String and String(v) in RESOLUTION_PRESETS:
				return v
		"invert_colors":
			if v is bool:
				return v
	return DEFAULTS.get(key)


static func save() -> void:
	var cfg := ConfigFile.new()
	for k: String in _data.keys():
		cfg.set_value(_SECTION, k, _data[k])
	if cfg.save(_PATH) != OK:
		push_warning("GameSettings: 设置保存失败（%s·磁盘只读/占用?）——本次改动仅内存生效" % _PATH)   # 终审修复：保存失败不再静默


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


## 仅重应用三个音量键（AudioEvents.ensure_buses 建完总线后回调·不碰窗口/主色）。
static func apply_volumes() -> void:
	for k: String in ["master_volume", "music_volume", "sfx_volume"]:
		_apply_one(k)


## 确保所有入口（包括编辑器直接 F6 某个战斗场景）使用同一套 2D 设计画布。
## 这里只设置画布映射，不读取存档、不切换窗口模式，也不会改动用户分辨率。
static func ensure_canvas_scaling() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var win := tree.root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = DESIGN_SIZE


static func _apply_one(key: String) -> void:
	match key:
		"master_volume":
			_apply_bus_volume("Master", float(get_value("master_volume")))
		"music_volume":
			_apply_bus_volume("Music", float(get_value("music_volume")))
		"sfx_volume":
			_apply_bus_volume("SFX", float(get_value("sfx_volume")))
		"window_mode", "resolution":
			_apply_display()
		"invert_colors":
			BootResult.invert_colors = bool(get_value("invert_colors"))


## 设音量总线。总线尚未建时静默跳过（值已持久化·AudioEvents.ensure_buses 建完会回灌）。
static func _apply_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.0)
	if v > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(v, 0.0001, 1.0)))


## 应用显示模式 + 分辨率（window_mode / resolution 任一变动都整体重应用）。
## 设计画布恒 1920×1080：先确保 content_scale 等比缩放接管（工程未配 stretch），
## 再按模式切窗口——窗口化时用 resolution 设尺寸并居中；全屏两档由系统接管尺寸。
static func _apply_display() -> void:
	ensure_canvas_scaling()
	if DisplayServer.get_name() == "headless":
		return   # GUT / CLI 截图等无窗环境跳过
	match String(get_value("window_mode")):
		"fullscreen":
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var sz := parse_resolution(String(get_value("resolution")))
			if DisplayServer.window_get_size() != sz:
				DisplayServer.window_set_size(sz)
				# 居中到当前屏幕
				var scr_pos := DisplayServer.screen_get_position()
				var scr_sz := DisplayServer.screen_get_size()
				DisplayServer.window_set_position(scr_pos + (scr_sz - sz) / 2)


## "1920x1080" → Vector2i；非法值回退设计画布。
static func parse_resolution(s: String) -> Vector2i:
	var parts := s.split("x")
	if parts.size() == 2 and int(parts[0]) > 0 and int(parts[1]) > 0:
		return Vector2i(int(parts[0]), int(parts[1]))
	return DESIGN_SIZE
